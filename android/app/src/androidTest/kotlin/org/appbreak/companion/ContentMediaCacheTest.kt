package org.appbreak.companion
import android.test.AndroidTestCase
import android.graphics.Bitmap
import java.io.ByteArrayOutputStream
import java.io.File
@Suppress("DEPRECATION")
class ContentMediaCacheTest: AndroidTestCase() {
    override fun tearDown(){File(context.cacheDir,"content-media").deleteRecursively();super.tearDown()}
    fun testPersistentImageWithoutNetwork() {
        val bitmap=Bitmap.createBitmap(2,2,Bitmap.Config.ARGB_8888)
        val out=ByteArrayOutputStream();bitmap.compress(Bitmap.CompressFormat.PNG,100,out);bitmap.recycle()
        val bytes=out.toByteArray();val url="https://example.invalid/offline.png"
        ContentMediaCache.store(context,url,bytes)
        assertTrue(bytes.contentEquals(ContentMediaCache.cached(context,url)!!))
        // Invalid DNS would fail if load attempted a network request instead of cache.
        assertTrue(bytes.contentEquals(ContentMediaCache.load(context,url)))
    }
    fun testInvalidImagesAndUrls() {
        assertFalse(ContentMediaCache.valid("<script>bad</script>".toByteArray()))
        assertFalse(ContentMediaCache.valid(ByteArray(ContentMediaCache.MAX_IMAGE+1)))
        for(url in listOf("file:///etc/passwd","http://example.org/a.png","https://name:secret@example.org/a","https://example.org:8080/a")) {
            try{ContentMediaCache.checkedUrl(url);fail("Accepted unsafe URL")}catch(_:IllegalArgumentException){}
        }
    }
}
