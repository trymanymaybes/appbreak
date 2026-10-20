// SPDX-License-Identifier: Apache-2.0
package org.appbreak.companion
import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import java.io.File

/** Only explicitly prepared cache attachments can leave via temporary URI grants. */
class ShareProvider: ContentProvider() {
    override fun onCreate()=true
    private fun file(uri:Uri):File {
        val segments=uri.pathSegments
        require(segments.size==2 && segments[0].matches(Regex("[a-f0-9-]{36}")) && segments[1]=="voice-note.m4a")
        return File(context!!.cacheDir,"shares/${segments[0]}/voice-note.m4a").also { require(it.isFile) }
    }
    override fun getType(uri:Uri)="audio/mp4"
    override fun openFile(uri:Uri,mode:String):ParcelFileDescriptor { require(mode=="r");return ParcelFileDescriptor.open(file(uri),ParcelFileDescriptor.MODE_READ_ONLY) }
    override fun query(uri:Uri,projection:Array<out String>?,selection:String?,selectionArgs:Array<out String>?,sortOrder:String?):Cursor {
        val f=file(uri); return MatrixCursor(arrayOf(OpenableColumns.DISPLAY_NAME,OpenableColumns.SIZE)).apply { addRow(arrayOf<Any>("voice-note.m4a",f.length())) }
    }
    override fun insert(uri:Uri,values:ContentValues?):Uri?=throw UnsupportedOperationException()
    override fun update(uri:Uri,values:ContentValues?,selection:String?,selectionArgs:Array<out String>?):Int=throw UnsupportedOperationException()
    override fun delete(uri:Uri,selection:String?,selectionArgs:Array<out String>?):Int=throw UnsupportedOperationException()
}
