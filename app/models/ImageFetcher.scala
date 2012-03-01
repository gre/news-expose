package models

import play.api.cache.Cache
import play.api._
import play.api.libs._
import play.api.libs.ws._
import play.api.libs.ws.Response
import play.api.libs.concurrent._
import play.api.Play.current 

object ImageFetcher {
  // Fetch a ImageExtractor lazily (with cache)
  def fetch(url: String)(implicit extractor: ImageExtractor): Promise[Option[Image]] =
    cacheValue(url).map(Promise.pure(_)).getOrElse(retrieve(url))

  def retrieve(url: String)(implicit extractor: ImageExtractor): Promise[Option[Image]] =
    extractor.getImage(url).map(cacheValue(url, _))

  // Get a cache value
  def cacheValue(url: String)(implicit r:ImageExtractor): Option[Option[Image]] = cache.getAs[Option[Image]](url)

  // Set the cache value
  def cacheValue(url: String, image:Option[Image])(implicit r:ImageExtractor):Option[Image] = {
    cache.set(url, image, r.cacheExpirationSeconds)
    image 
  }
  val cache = Cache
}
