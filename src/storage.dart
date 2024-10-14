library storage;

import "dart:html" show window, Storage, document;
import "dart:io";
// import "dart:js_interop" show NullableUndefineableJSAnyExtension;
import "dart:convert" show jsonEncode;

import "lib/backendless.dart" as bk;
import "lib/types.dart";

bool __usingLocalStorage = false;

string __gruvlink = "https://camo.githubusercontent.com/410b3ab80570bcd5b470a08d84f93caa5b4962ccd994ebceeb3d1f78364c2120/687474703a2f2f692e696d6775722e636f6d2f776136363678672e706e67";

string __linksPreset = createLinkPreset([

    __link("github"     , "https://github.com/al1-ce"                          , "work"  , 10),
    __link("gitlab"     , "https://gitlab.com"                                 , "work"  , 9) ,
    __link("atheos"     , "https://al1-ce.dev"                                 , "work"  , 8) ,
    __link("regex"      , "https://regex101.com"                               , "work"  , 7) ,
    __link("localhost"  , "http://127.0.0.1:8080"                              , "work"  , 6) ,
    __link("backendless", "https://eu-develop.backendless.com/app/"            , "work"  , 5) ,

    __link("youtube"    , "https://youtube.com"                                , "social", 9) ,
    __link("twitter"    , "https://twitter.com"                                , "social", 8) ,
    __link("telegram"   , "https://web.telegram.org/a/"                        , "social", 7) ,
    __link("discord"    , "https://discord.com/app"                            , "social", 6) ,
    __link("twitch"     , "https://twitch.tv"                                  , "social", 5) ,
    __link("mail"       , "https://mail.com"                                   , "social", 4) ,
    __link("neocities"  , "https://neocities.org"                              , "social", 3) ,
    __link("dev.to"     , "https://dev.to"                                     , "social", 2) ,

    __link("rund"       , "https://run.dlang.io"                               , "tool"  , 9) ,
    __link("blackboard" , "https://excalidraw.com"                             , "tool"  , 8) ,
    __link("stackedit"  , "https://stackedit.io/app"                           , "tool"  , 7) ,
    __link("material"   , "https://fonts.google.com/icons"                     , "tool"  , 6) ,
    __link("csshex"     , "https://isotropic.co/tool/hex-color-to-css-filter/" , "tool"  , 5) ,
    __link("jscanvas"   , "https://natto.dev"                                  , "tool"  , 4) ,

    __link("dub"        , "https://code.dlang.org"                             , "docs"  , 9) ,
    __link("icons"      , "https://simpleicons.org"                            , "docs"  , 8) ,
    __link("badgen"     , "https://badgen.net"                                 , "docs"  , 7) ,
    __link("badge"      , "https://shields.io"                                 , "docs"  , 6) ,
    __link("gruvbox"    , __gruvlink                                           , "docs"  , 5) ,
    __link("charm"      , "https://charm.sh"                                   , "docs"  , 4) ,

]);

string createLinkPreset(List<string> val) {
    return "[" + val.join(",") + "]";
}

int __link_idx = 7890234;
string __link(string name, string href, string category, int priority) {
    ++__link_idx;
    return """{
        "created": 0,
        "objectId": "asm$__link_idx",
        "name": "$name",
        "href": "$href",
        "category": "$category",
        "priority": $priority
    }""";
}

/*
__storageCache = {
    table1: jsarr[ Map<string, dynamic>{
        created - DateTime.millisecondsSinceEpoch,
        objectId - object id,
        ...
    }, ... ],
    ...
}
*/
Map<string, JSON> __storageCache = new Map<string, JSON>();

bool isAvailable() { return true; }
// bool isAvailable() { return !window.localStorage.isUndefinedOrNull; }
bool isUsingLocal() { return __usingLocalStorage; }

void init(bool shouldUseLocalStorage) {
    if (isAvailable()) {
        __usingLocalStorage = shouldUseLocalStorage;
    } else {
        throw(new Exception("Local storage is not available on this device"));
    }
    if (__usingLocalStorage) {
        Storage storage = window.localStorage;
        if (!storage.containsKey("notes")) storage["notes"] = "[]";
        if (!storage.containsKey("links")) storage["links"] = __linksPreset;
        if (!storage.containsKey("todo")) storage["todo"] = "[]";
        __storageCache["notes"] = __getJSON("notes");
        __storageCache["links"] = __getJSON("links");
        __storageCache["todo"] = __getJSON("todo");
    } else {
        bk.initApp("modernthought");
    }
}

int __msecHash = 0;

Future<string> add(string table, Map<string, dynamic> val) async {
    if (__usingLocalStorage) {
        val["created"] = DateTime.now().millisecondsSinceEpoch;
        val["objectId"] = val["created"].toString() + __msecHash.toString();
        ++__msecHash;

        (__storageCache[table]?["jsarr"] as List).add(val);
        __storeJSON(table, __storageCache[table] as JSON);
        return val["objectId"];
    } else {
        return (await bk.Data.add(table, [val]))["jsarr"][0];
    }
}

Future<void> update(string table, string id, Map<string, dynamic> val) async {
    if (__usingLocalStorage) {
        List arr = __storageCache[table]?["jsarr"];
        for (int i = 0; i < arr.length; ++i) {
            if (arr[i]["objectId"] == id) {
                (arr[i] as Map<string, dynamic>).addAll(val);
                break;
            }
        }

        __storeJSON(table, __storageCache[table] as JSON);
    } else {
        await bk.Data.update(table, id, val);
    }
}

Future<JSON> get(string table, [bk.DataQuery? query = null]) async {
    if (__usingLocalStorage) {
        JSON j = __storageCache[table] as JSON;
        if (query != null) {
            bk.DataQuery q = query;
            (j["jsarr"] as List).sort((a, b) {
                List<string> s = (q.query["sortBy"] as string).split(",");
                int priority = 0;
                for (int i = 0; i < s.length; ++i) {
                    string prop = s[i];
                    int w = (s.length - i) * 5;
                    if (a[prop] is string) {
                        priority += (a[prop] as string).compareTo((b[prop] as string)) * w;
                    } else {
                        priority += w * ((a[prop] - b[prop]) as int).sign;
                    }
                }
                return priority.sign;
            });
        }
        return j;
    } else {
        if (query != null) {
            return await bk.Data.find(table, query);
        } else {
            return await bk.Data.data(table);
        }
    }
}

Future<void> delete(string table, string id) async {
    if (__usingLocalStorage) {
        int idx = -1;
        List arr = __storageCache[table]?["jsarr"];
        for (int i = 0; i < arr.length; ++i) {
            if (arr[i]["objectId"] == id) {
                idx = i;
                break;
            }
        }

        if (idx != -1) (__storageCache[table]?["jsarr"] as List).removeAt(idx);

        __storeJSON(table, __storageCache[table] as JSON);
    } else {
        await bk.Data.delete(table, id);
    }
}

Future<int> count(string table) async {
    if (__usingLocalStorage) {
        return ((__storageCache[table]?["jsarr"] as List).length) as int;
    } else {
        return await bk.Data.count(table, "");
    }
}

Future<void> exportDB() async {
    JSON tools = await getTableData("tools");
    JSON notes = await getTableData("notes");
    JSON links = await getTableData("links");
    JSON todo  = await getTableData("todo");

    exportFile("homepage-export-todo.csv", todo);
    exportFile("homepage-export-tools.csv", tools);
    exportFile("homepage-export-notes.csv", notes);
    exportFile("homepage-export-links.csv", links);
}

Future<void> exportFile(string name, JSON data) async {
    var fields = data["jsarr"];
    string csv = "";
    bool didHeader = false;
    for (var field in fields) {
        if (!didHeader) {
            for (var key in field.keys) {
                csv += key + ",";
            }
            csv = csv.substring(0, csv.length - 1);
            csv += "\n";
            didHeader = true;
        }

        for (var key in field.keys) {
            bool shoudSurround = field[key] is string && (field[key].contains(",") || field[key].contains("\n"));
            if (shoudSurround) { csv += '\"'; }
            csv += field[key].toString().replaceAll("\n", "\\n");
            if (shoudSurround) { csv += '\"'; }
            csv += ",";
        }

        csv = csv.substring(0, csv.length - 1);
        csv += "\n";
    }
    csv = csv.substring(0, csv.length - 1);

    // window.open(, "_blank");
    var link = document.createElement("a");
    link.setAttribute("href", Uri.dataFromString(csv, mimeType: "text/plain").toString());
    link.setAttribute("download", name);
    link.click();
    link.remove();
}

Future<JSON> getTableData(string table) async {
    if (__usingLocalStorage) {
        return get(table);
    } else {
        JSON j = { "jsarr": [] };
        int cnt = await count(table);
        for (int N = 0; N < (cnt / 100 + 1); ++N) {
            JSON data = await get(table, bk.DataQuery().pageSize(100).offset(N * 100));
            var fields = data["jsarr"];
            // print(fields);
            j["jsarr"] += fields;
        }
        return j;
    }
}

void __storeJSON(string table, JSON value) {
    string j = jsonEncode(value);
    window.localStorage[table] = j;
}

JSON __getJSON(string table) {
    string j = window.localStorage[table] as string;
    return bk.jsonDecode(j);
}
