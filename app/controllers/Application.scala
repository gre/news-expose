package controllers

import play.api._
import play.api.mvc._
import play.api.libs.json._
import play.api.libs.json.Writes._
import Json._

import utils._
import models._

import org.jsoup.Jsoup
import org.jsoup.nodes._
import org.jsoup.select.Elements

import play.api.libs.concurrent._

import scala.util.parsing.json._

/**
 * Link and Image joined class
 */
case class LinkWithImage(link: Link, image: Image)

case class NewsSource(
  id: String,
  linksExtractor: LinksExtractor, 
  imageExtractor: ImageExtractor) {
  lazy val jsonURI = linksExtractor match {
    case RssRetriever(url) => "/current.json?source="+id+"&url="+url
    case _ => "/current.json?source="+id
  }
  lazy val titleHtml = views.html.title(this)
}

object Sources {
  val staticSourcesList = List(
    NewsSource("hackernews", HackerNewsRetriever("/news"), ScreenshotExtractor),
    NewsSource("reddit", RedditRetriever("/"), ScreenshotExtractor),
    NewsSource("googlenews", RssRetriever("http://news.google.com/news?output=rss"), ScreenshotExtractor),
    NewsSource("playframework", RssRetriever("http://www.playframework.org/community/planet.rss"), ScreenshotExtractor)
  )
  val staticSources = staticSourcesList map { s => (s.id, s) } toMap

  val default = staticSources("hackernews")

  def getSourceFromRequest(source: Option[String], url: Option[String]): Option[NewsSource] =
    source.flatMap(_ match {
      case "rss" =>
        url.map( url =>
          Some(NewsSource("rss", RssRetriever(url), ScreenshotExtractor))
        ).getOrElse(None)
      case source if(staticSources contains source) => 
        Some(staticSources(source))
      case _ =>
        None
    })
}

object Application extends Controller {
  
  def index = Action { (request) =>
    val source = request.queryString.get("source").flatMap(_.headOption)
    val url = request.queryString.get("url").flatMap(_.headOption)
    val sourceResult = Sources.getSourceFromRequest(source, url).getOrElse(Sources.default)
    Ok(views.html.index(sourceResult))
  }

  def indexWithSource(source: String) = Action { (request) =>
    val url = request.queryString.get("url").flatMap(_.headOption)
    val sourceResult = Sources.getSourceFromRequest(Some(source), url).getOrElse(Sources.default)
    Ok(views.html.index(sourceResult))
  }

  def get(format: String) = Action { (request) =>
    val source = request.queryString.get("source").flatMap(_.headOption)
    val url = request.queryString.get("url").flatMap(_.headOption)
    val sourceResult = Sources.getSourceFromRequest(source, url).getOrElse(Sources.default)
    AsyncResult(
      getResult(sourceResult).extend(promise => {
        promise.value match {
          case Redeemed(links) => format match {
            case "json" => Ok( toJson(links) )
            case _ => Status(415)("Format Not Supported")
          }
        }
      })
    )
  }

  implicit def linkWithImageWrites: Writes[LinkWithImage] = new Writes[LinkWithImage] {
    def writes(o: LinkWithImage) = JsObject(List(
      ("url" -> JsString(o.link.url)),
      ("weight" -> JsNumber(o.link.weight)),
      ("title" -> JsString(o.link.title)),
      ("feedbackLink" -> JsString(o.link.feedbackLink)),
      ("feedbackText" -> JsString(o.link.feedbackText)),
      ("image" -> JsString(o.image.url))
    ))
  }

  def getResult(source: NewsSource): Promise[List[LinkWithImage]] = {
    LinksFetcher.fetch(source.linksExtractor).flatMap(links => {
      Logger.debug(links.length+" links found.");
      val images = links.sortWith( _.weight > _.weight ).map(link => 
          ImageFetcher.fetch(link.url)(source.imageExtractor).map( (link, _) )
        ).sequence.map(_.flatMap(_ match {
        case (link, Some(img)) => Some(LinkWithImage(link, img))
        case _ => None
      }))
      images.map(images => Logger.debug(images.length+" images found."));
      images
    })
  }


}
