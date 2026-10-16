package com.example.my_location_record

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.util.TimeZone

class DatabaseHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        private const val DATABASE_NAME = "locations.db"
        private const val DATABASE_VERSION = 3
        const val TABLE_NAME = "location_points"
        
        const val COLUMN_ID = "id"
        const val COLUMN_LAT = "latitude"
        const val COLUMN_LNG = "longitude"
        const val COLUMN_TIME = "timestamp"
        const val COLUMN_OFFSET = "timezone_offset_minutes"
    }

    override fun onCreate(db: SQLiteDatabase) {
        val createTable = "CREATE TABLE $TABLE_NAME (" +
                "$COLUMN_ID INTEGER PRIMARY KEY AUTOINCREMENT, " +
                "$COLUMN_LAT REAL, " +
                "$COLUMN_LNG REAL, " +
                "$COLUMN_TIME INTEGER, " +
                "$COLUMN_OFFSET INTEGER)"
        db.execSQL(createTable)
    }

    override fun onUpgrade(
        db: SQLiteDatabase,
        oldVersion: Int,
        currentVersion: Int
    ) {
        if (!tableExists(db, TABLE_NAME)) {
            onCreate(db)
        }

        if (!columnExists(db, TABLE_NAME, COLUMN_OFFSET)) {
            db.execSQL(
                "ALTER TABLE $TABLE_NAME " +
                "ADD COLUMN $COLUMN_OFFSET INTEGER NOT NULL DEFAULT 0"
            )
        }
    }

    private fun tableExists(
        db: SQLiteDatabase,
        tableName: String
    ): Boolean {
        db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
            arrayOf(tableName)
        ).use { cursor ->
            return cursor.moveToFirst()
        }
    }

    private fun columnExists(
        db: SQLiteDatabase,
        tableName: String,
        columnName: String
    ): Boolean {
        db.rawQuery("PRAGMA table_info($tableName)", null).use { cursor ->
            val nameIndex = cursor.getColumnIndex("name")

            while (cursor.moveToNext()) {
                if (cursor.getString(nameIndex) == columnName) {
                    return true
                }
            }
        }

        return false
    }

    fun insertLocation(lat: Double, lng: Double, time: Long) {
        val db = writableDatabase
        
        val tzOffsetMillis = TimeZone.getDefault().getOffset(time)
        val tzOffsetMinutes = (tzOffsetMillis / (1000 * 60)).toInt()

        val values = ContentValues().apply {
            put(COLUMN_LAT, lat)
            put(COLUMN_LNG, lng)
            put(COLUMN_TIME, time)
            put(COLUMN_OFFSET, tzOffsetMinutes)
        }
        db.insert(TABLE_NAME, null, values)
        db.close()
    }
}