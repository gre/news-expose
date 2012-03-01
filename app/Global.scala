import play.api._
import play.api.Play.current
import akka.actor._
import akka.actor.Actor._
import akka.util._
import java.util.concurrent.TimeUnit._

import controllers._
import models._

object Global extends GlobalSettings {
  val actorSystem = ActorSystem("fetcher")
  val linksFetchScheduler = actorSystem.actorOf(Props[LinksFetchScheduler])

  override def onStart(app: Application) {
    actorSystem.scheduler.schedule(Duration(1, SECONDS), Duration(10, SECONDS), linksFetchScheduler, "fetch");
    //actorSystem.scheduler.schedule(linksFetchScheduler, "fetch", 1, 10, TimeUnit.SECONDS)
  }
  override def onStop(app: Application) {
  }
}

class LinksFetchScheduler extends Actor {
  var i = 0
  def getNextLinksFetch() = {
    val source = Sources.staticSourcesList(i)
    i = if(i+1 < Sources.staticSourcesList.length) i+1 else 0
    source
  }
  val linksFetch = Global.actorSystem.actorOf(Props[LinksFetch])

  def receive = {
    case "fetch" => {
      linksFetch ! getNextLinksFetch()
    }
  }
}

class LinksFetch extends Actor {
  def receive = {
    case source:NewsSource => 
      Logger("LinksFetch").debug("fetching "+source)
      LinksFetcher.fetch(source.linksExtractor).map(_.map(link => ImageFetcher.fetch(link.url)(source.imageExtractor)))
  }
}
