package org.appbreak.companion

import android.content.Context
import android.graphics.BitmapFactory
import java.io.File
import java.net.URI
import java.security.MessageDigest
import javax.net.ssl.HttpsURLConnection

/** Public image bytes only. No Store access, cookies, credentials or external intents. */
object ContentMediaCache {
    const val MAX_IMAGE = 4 * 1024 * 1024
    const val MAX_CACHE = 20L * 1024 * 1024
    fun checkedUrl(raw:String):URI {
        require(raw.length in 1..2000)
        val u=URI(raw)
        require(u.scheme=="https" && !u.host.isNullOrEmpty() && u.userInfo==null && u.port == -1)
        return u
    }
    private fun dir(c:Context)=File(c.cacheDir,"content-media").also { it.mkdirs() }
    private fun file(c:Context,url:String):File {
        checkedUrl(url)
        val name=MessageDigest.getInstance("SHA-256").digest(url.toByteArray(Charsets.UTF_8)).joinToString(""){"%02x".format(it)}
        return File(dir(c),name)
    }
    fun valid(bytes:ByteArray):Boolean {
        if(bytes.isEmpty() || bytes.size>MAX_IMAGE)return false
        val info=BitmapFactory.Options().apply { inJustDecodeBounds=true }
        BitmapFactory.decodeByteArray(bytes,0,bytes.size,info)
        return info.outWidth in 1..4096 && info.outHeight in 1..4096 && info.outWidth.toLong()*info.outHeight<=8_000_000
    }
    @Synchronized fun cached(c:Context,url:String):ByteArray? {
        val f=file(c,url)
        if(!f.isFile)return null
        if(f.length()>MAX_IMAGE){ f.delete();return null }
        val bytes=f.readBytes()
        if(!valid(bytes)){f.delete();return null}
        f.setLastModified(System.currentTimeMillis())
        return bytes
    }
    @Synchronized fun store(c:Context,url:String,bytes:ByteArray) {
        require(valid(bytes)) { "Unsupported or oversized image" }
        val target=file(c,url)
        val files=dir(c).listFiles()?.filter {it.isFile && it!=target}?.sortedBy {it.lastModified()} ?: emptyList()
        var total=files.sumOf {it.length()}+bytes.size
        for(f in files) { if(total<=MAX_CACHE)break;val size=f.length();if(f.delete())total-=size }
        val temp=File.createTempFile("image-",".tmp",dir(c))
        try { temp.writeBytes(bytes);check(temp.renameTo(target)) } finally {temp.delete()}
    }
    fun load(c:Context,raw:String):ByteArray {
        cached(c,raw)?.let{return it}
        val connection=checkedUrl(raw).toURL().openConnection() as HttpsURLConnection
        try {
            connection.instanceFollowRedirects=false
            connection.connectTimeout=8000;connection.readTimeout=8000
            connection.setRequestProperty("Accept-Encoding","identity")
            require(connection.responseCode==200 && connection.contentLengthLong<=MAX_IMAGE)
            require(connection.contentEncoding==null || connection.contentEncoding=="identity")
            val out=java.io.ByteArrayOutputStream()
            val deadline=android.os.SystemClock.elapsedRealtime()+20000
            connection.inputStream.use { input ->
                val buffer=ByteArray(4096)
                while(true){require(android.os.SystemClock.elapsedRealtime()<=deadline);val n=input.read(buffer);if(n<0)break;require(out.size()+n<=MAX_IMAGE);out.write(buffer,0,n)}
            }
            val bytes=out.toByteArray();store(c,raw,bytes);return bytes
        } finally {connection.disconnect()}
    }
}
