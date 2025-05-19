// Content from https://github.com/tekartik/sqflite/blob/master/sqflite_common_ffi_web/web/sqflite_sw.js
importScripts("https://cdn.jsdelivr.net/npm/sql.js@1.8.0/dist/sql-wasm.js");
let db = null;
self.onmessage = function(event) {
  const data = event.data;
  switch (data.command) {
    case 'open':
      const options = data.options || {};
      const locateFile = (filename) => {
        if (filename === 'sql-wasm.wasm') {
          return options.sqlite3WasmPath || 'sqlite3.wasm';
        }
        return filename;
      };
      initSqlJs({
        locateFile: locateFile
      }).then(function(SQL) {
        db = new SQL.Database();
        self.postMessage({result: {}});
      }).catch(function(error) {
        self.postMessage({error: error.toString()});
      });
      break;
    case 'close':
      if (db) {
        db.close();
        db = null;
      }
      self.postMessage({result: {}});
      break;
    case 'execute':
      if (db) {
        try {
          db.exec(data.sql);
          self.postMessage({result: {}});
        } catch (error) {
          self.postMessage({error: error.toString()});
        }
      } else {
        self.postMessage({error: 'Database not open'});
      }
      break;
  }
};