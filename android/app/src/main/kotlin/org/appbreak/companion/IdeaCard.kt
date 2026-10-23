package org.appbreak.companion
import android.graphics.*
import android.text.*
import java.io.ByteArrayOutputStream
object IdeaCard {
    fun render(title:String,text:String):ByteArray {
        val paint=TextPaint(Paint.ANTI_ALIAS_FLAG).apply {color=Color.rgb(25,38,42);textSize=32f}
        val layout=StaticLayout.Builder.obtain(text,0,text.length,paint,1000).setLineSpacing(8f,1f).build()
        val bitmap=Bitmap.createBitmap(1120,layout.height+260,Bitmap.Config.ARGB_8888)
        val canvas=Canvas(bitmap);canvas.drawColor(Color.rgb(248,244,233))
        canvas.drawText(title,60f,75f,paint);canvas.save();canvas.translate(60f,130f);layout.draw(canvas);canvas.restore()
        val output=ByteArrayOutputStream();bitmap.compress(Bitmap.CompressFormat.PNG,100,output);bitmap.recycle();return output.toByteArray()
    }
}
