// SPDX-License-Identifier: Apache-2.0
package org.appbreak.companion

import android.content.Context
import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import org.json.JSONObject

class Store(context: Context): SQLiteOpenHelper(context, "companion.db", null, 1) {
    override fun onCreate(db: SQLiteDatabase) { db.execSQL("CREATE TABLE state (id INTEGER PRIMARY KEY CHECK(id=1), body TEXT NOT NULL)") }
    override fun onUpgrade(db: SQLiteDatabase, old: Int, new: Int) { error("Unsupported database upgrade") }
    fun read(): JSONObject = readableDatabase.rawQuery("SELECT body FROM state WHERE id=1", null).use {
        if (it.moveToFirst()) JSONObject(it.getString(0)) else JSONObject().put("schemaVersion",1).put("revision",0)
    }
    fun write(value: JSONObject, replace: Boolean = false) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            val revision = read().optInt("revision")
            check(replace || value.optInt("revision") == revision) { "Data changed; retry your action" }
            value.put("revision", revision + 1)
            val values = ContentValues().apply { put("id",1); put("body",value.toString()) }
            db.insertWithOnConflict("state",null,values,SQLiteDatabase.CONFLICT_REPLACE)
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }
}
