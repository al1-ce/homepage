library backendless;

import "package:http/http.dart" as http;

import "dart:convert" show jsonEncode, utf8, HtmlEscape;
import "dart:convert" as dconv show jsonDecode;

import "dart:js_interop" show JSArray;

import "types.dart";
import "cookies.dart";

// /// Sets server URL to custom domain (WITHOUT https://)
// void setServer(string server) {
//     BackendlessDB.serverURL = server;
// }
//
// /// Sets server URL to default EU Backendless domain
// void setServerEU() {
//     BackendlessDB.serverURL = "eu-api.backendless.com";
// }
//
// /// Sets server URL to default US Backendless domain
// void setServerUS() {
//     BackendlessDB.serverURL = "api.backendless.com";
// }
//
// class BackendlessDB {
//     static string serverURL = "api.backendless.com";
//
//     static Uri serverURI([string httpPath = ""]) {
//         return Uri.https(serverURL, httpPath);
//     }
// }



// /// Initialises app with AppId and Key
// void initAppByKey(string appId, string apiKey) {
//
// }

JSON jsonDecode(string source, {Object? reviver(Object? key, Object? value)?}) {
    var json = dconv.jsonDecode(source, reviver: reviver);
    if (json is JSArray) {
        return {"jsarr": json};
    } else {
        return json;
    }
}

// const HtmlEscape _htmlEscape = HtmlEscape();

/// Initialises app with subdomain (i.e appsubdomain in appsubdomain.backendless.app)
void initApp(string appSubDomain, [Function(bool)? loginStatus = null]) {
    BackendlessDB.serverURL = appSubDomain + ".backendless.app";

    BackendlessDB.userToken = getCookie("userToken");

    // Automatically checks login validity to allow user-specific api usage
    UserService.isValidLogin();

    if (!BackendlessDB.userValid() && loginStatus != null) {
        loginStatus(false);
    } else if (loginStatus != null){
        loginStatus(true);
    }
}

class BackendlessDB {
    static string serverURL = "";

    /// Returns server path wrapped in URI
    static Uri serverURI([string httpPath = ""]) {
        if (serverURL == "") throw new Exception("App must be initialised");

        return Uri.https(serverURL, httpPath);
    }

    /// Returns server path wrapped in URI including httpPath and Query
    static Uri serverQURI(string httpPath, Map<string, string> queryParameters) {
        if (serverURL == "") throw new Exception("App must be initialised");

        return Uri.https(serverURL, httpPath, queryParameters);
    }

    static string userToken = "";

    /// Checks if user token is not empty
    static bool userValid() {
        return userToken != "";
    }
}

class UserService {

    /// Loggin user (set `stayLoggedFor` to 0 to disable staying logged)
    static Future<JSON> login(string userEmail, string userPass, {int stayLoggedFor = 30}) async {
        http.Response response = await http.post(BackendlessDB.serverURI("api/users/login"), headers: {
            "Content-Type": "application/json"
        }, body: jsonEncode({
            "login": userEmail,
            "password": userPass,
        }));

        JSON j = jsonDecode(utf8.decode(response.bodyBytes));

        if (j.containsKey("user-token")) {
            BackendlessDB.userToken = j["user-token"] as string;
            if (stayLoggedFor > 0) {
                setCookie("userToken", BackendlessDB.userToken, stayLoggedFor);
            }
        }

        return j;
    }

    /// Loggs user out
    static Future<void> logout() async {
        if (!BackendlessDB.userValid()) {
            // return {"code": 3023, "message": "User is already logged out."};
            return;
        }

        http.Response response = await http.get(
            BackendlessDB.serverURI("api/users/logout"), headers: {"user-token": BackendlessDB.userToken}
        );

        // JSON j = jsonDecode(utf8.decode(response.bodyBytes));

        // return j;
        return;
    }

    /// DO NOT USE, CREATES DUMMY ACCOUNTS
    static loginGuest({int stayLoggedFor = 30}) async {
        http.Response response = await http.post(BackendlessDB.serverURI("api/users/register/guest"));

        JSON j = jsonDecode(utf8.decode(response.bodyBytes));

        if (j.containsKey("user-token")) {
            BackendlessDB.userToken = j["user-token"] as string;
            if (stayLoggedFor > 0) {
                setCookie("userToken", BackendlessDB.userToken, stayLoggedFor);
            }
        }

        return j;
    }

    /// Checks if current login is valid
    static Future<bool> isValidLogin() async {
        if (BackendlessDB.userToken == "") {
            return false;
        }
        http.Response response = await http.get(
            BackendlessDB.serverURI("api/users/isvalidusertoken/" + BackendlessDB.userToken)
            );
        string r = utf8.decode(response.bodyBytes);
        bool isLoggedIn = r == "true";

        if (!isLoggedIn) {
            // delCookie("userToken");
            BackendlessDB.userToken = "";
        }

        return isLoggedIn;
    }
}

/// Static DataBase class
class Data {
    /// Returns all data in table
    static Future<JSON> data(string table) async {
        Map<string, string> headers = {
            "Content-Type": "application/json"
        };

        if (BackendlessDB.userValid()) {
            headers["user-token"] = BackendlessDB.userToken;
        }

        http.Response response = await http.get(BackendlessDB.serverURI("api/data/" + table), headers: headers);

        JSON j = jsonDecode(utf8.decode(response.bodyBytes));

        return j;
    }

    /// Returns first object in table
    static Future<JSON> objectFirst(string table) async {
        return await data(table + "/first");
    }

    /// Returns last object in table
    static Future<JSON> objectLast(string table) async {
        return await data(table + "/last");
    }

    /// Returns object with set ID
    static Future<JSON> objectById(string table, string objID) async {
        return await data(table + "/" + objID);
    }

    /// Returns json based on DataQuery
    static Future<JSON> find(string table, DataQuery query) async {
        Map<string, string> headers = {
            "Content-Type": "application/json"
        };

        if (BackendlessDB.userValid()) {
            headers["user-token"] = BackendlessDB.userToken;
        }

        http.Response response = await http.get(BackendlessDB.serverQURI("api/data/" + table, query.query), headers: headers);

        JSON j = jsonDecode(utf8.decode(response.bodyBytes));

        return j;
    }

    /// Adds new rows to table
    static Future<JSON> add(string table, List<Map<string, dynamic>> rows) async {
        Map<string, string> headers = {
            "Content-Type": "application/json"
        };

        if (BackendlessDB.userValid()) {
            headers["user-token"] = BackendlessDB.userToken;
        }

        http.Response response = await http.post(
            BackendlessDB.serverURI("api/data/bulk/" + table), headers: headers, body: jsonEncode(rows)
            );

        JSON j = jsonDecode(utf8.decode(response.bodyBytes));

        return j;
    }

    /// Updates single object
    static Future<JSON> update(string table, string objectID, Map<string, dynamic> properties) async {
        Map<string, string> headers = {
            "Content-Type": "application/json"
        };

        if (BackendlessDB.userValid()) {
            headers["user-token"] = BackendlessDB.userToken;
        }

        http.Response response = await http.put(
            BackendlessDB.serverURI("api/data/" + table + "/" + objectID), headers: headers, body: jsonEncode(properties)
            );

        JSON j = jsonDecode(utf8.decode(response.bodyBytes));

        return j;
    }

    /// Updates multiple objects, see "DataQuery.where()" for whereClause
    static Future<JSON> updateWhere(string table, string whereClause, Map<string, dynamic> p_data) async {
        Map<string, string> headers = {
            "Content-Type": "application/json"
        };

        if (BackendlessDB.userValid()) {
            headers["user-token"] = BackendlessDB.userToken;
        }

        http.Response response = await http.put(
            BackendlessDB.serverQURI(
                "api/data/bulk/" + table, {"where": whereClause}
                ), headers: headers, body: jsonEncode(p_data)
            );

        JSON j = jsonDecode(utf8.decode(response.bodyBytes));

        return j;
    }

    /// Updates objects or creates one if it doesn't exist. Each map in each row must have "objectId" property
    static Future<JSON> upsert(string table, List<Map<string, dynamic>> rows) async {
        Map<string, string> headers = {
            "Content-Type": "application/json"
        };

        if (BackendlessDB.userValid()) {
            headers["user-token"] = BackendlessDB.userToken;
        }


        http.Response response = await http.put(
            BackendlessDB.serverURI("api/data/" + table + "/upsert"), headers: headers, body: jsonEncode(rows)
            );

        JSON j = jsonDecode(utf8.decode(response.bodyBytes));

        return j;
    }

    /// Deletes single object
    static Future<JSON> delete(string table, string objectID) async {
        Map<string, string> headers = {
            "Content-Type": "application/json"
        };

        if (BackendlessDB.userValid()) {
            headers["user-token"] = BackendlessDB.userToken;
        }

        http.Response response = await http.delete(
            BackendlessDB.serverURI("api/data/" + table + "/" + objectID), headers: headers
            );

        JSON j = jsonDecode(utf8.decode(response.bodyBytes));

        return j;
    }

    /// Deletes multiple objects, see "DataQuery.where()" for whereClause
    static Future<JSON> deleteWhere(string table, string whereClause) async {
        Map<string, string> headers = {
            "Content-Type": "application/json"
        };

        if (BackendlessDB.userValid()) {
            headers["user-token"] = BackendlessDB.userToken;
        }

        http.Response response = await http.delete(
            BackendlessDB.serverQURI(
                "api/data/bulk/" + table, {"where": whereClause}
                ), headers: headers
            );

        JSON j = jsonDecode(utf8.decode(response.bodyBytes));

        return j;
    }

    /// Retrieves table schema
    static Future<JSON> retrieveSchema(string table) async {
        Map<string, string> headers = {
            "Content-Type": "application/json"
        };

        if (BackendlessDB.userValid()) {
            headers["user-token"] = BackendlessDB.userToken;
        }

        http.Response response = await http.get(
            BackendlessDB.serverURI("api/data/" + table + "/properties"), headers: headers
            );

        JSON j = jsonDecode(utf8.decode(response.bodyBytes));

        return j;
    }

    /// Counts number of matching objects, see "DataQuery.where()" for whereClause or set to empty for no clause
    static Future<int> count(string table, string whereClause, [bool distinct = false]) async {
        Map<string, string> headers = {
            "Content-Type": "application/json"
        };

        if (BackendlessDB.userValid()) {
            headers["user-token"] = BackendlessDB.userToken;
        }

        http.Response response;
        if (whereClause == "") {
            response = await http.post(
                BackendlessDB.serverURI(
                    "api/data/" + table + "/count"), headers: headers, body: jsonEncode({"distinct": distinct.toString()})
                );
        } else {
            response = await http.post(
                BackendlessDB.serverQURI(
                    "api/data/" + table + "/count", {"where": whereClause}
                    ), headers: headers, body: jsonEncode({"distinct": distinct.toString()})
                );
        }

        return int.parse(utf8.decode(response.bodyBytes)) as int;
    }

}

class Files {}

class Messaging {}

class Logging {}

class Cache {}

class DataQuery {
    Map<string, string> query = {};

    /// Initialises DataQuery
    DataQuery() {}

    /// Adds generic query in form of "p_query=argument"
    DataQuery add(string p_query, string argument) {
        query[p_query] = argument;
        // query[p_query] = _htmlEscape.convert(argument).replaceAll(" ", "%20");
        return this;
    }

    /** References object properties which should be returned with every object.
        Can be an agregate function
        Example
        ```
        > Normal property reference
            income
        > Average value
            Avg(columnName)
        > Calculate number of objects in table
            Count(columnName)
        > Calculates sum for set of objects
            Sum(columnName)
        > Min
            Min(columnName)
        > Max
            Max(columnName)
        > Agregate as (returns agregate as different property)
            Avg(income) as avgIncome

        ```
    */
    DataQuery props(List<string> properties) => add("props", properties.join(","));

    /// References object properties which are relations and
    /// should be initialized and returned with the parent object.
    DataQuery loadRelations(List<string> properties) => add("loadRelations", properties.join(","));

    /** Contains an SQL query (the where clause part) which is used to search for the objects.
        Consult https://backendless.com/docs/rest/data_search_with_where_clause.html
        And https://backendless.com/docs/rest/data_search_with_subquery.html
        Also see "props()" for agregate functions

        Example:
        ```
        > Value equals to string
            name = 'foo'
        > Value does not equals to string
            name != 'foo'
        > Value is not assigned
            name IS null
        > Value is assigned
            name IS NOT null
        > Value contains substring
            name LIKE '%foo%'
        > Value ends with substring
            name LIKE '%foo'
        > Value starts with substring
            name LIKE 'foo%'
        > Value is one of
            name IN ('value1', 'value2', 'value3)
            name = 'value1' OR name = 'value2' OR name = 'value3'
        > Compatison operations
            age = 21
            age > 21
            age < 21
            age != 21
            age >= 21
            age <= 21
        > Escaping a quote (replace ' with '')
            name = 'Charlie''s Angels'
        > And/Or/Is... Capitalisation doesn't matter,
        > but it's good practice to keep it capital.
            name = 'foo' AND name = 'baz'
            name = 'foo' OR name = 'baz'
            name = 'foo' OR (name = 'baz' AND age = 21)
        > Subquery example
            objectId in (Comment[author.email LIKE '%@backendless.com'].blogPost.objectId)
            columnName IN (TableName[internalWhereClause].columnOrRelatedColumnName.optionalcolumnName)
        ```
    */
    DataQuery where(string whereClause) => add("where", whereClause);

    /// Sets the page size which is the number of objects to be returned in the response.
    DataQuery pageSize(int size) => add("pageSize", size.toString());

    /// Lists properties by which the returned collection should be sorted by.
    DataQuery sortBy(List<string> properties) => add("sortBy", properties.join(","));

    /// Zero-based index of the object in the persistent store from which to run the search.
    DataQuery offset(int p_offset) => add("offset", p_offset.toString());

    /// Sets a condition on a aggregate function to filter groups (see "where()").
    DataQuery having(string havingClause) => add("having", havingClause);

    /// Used to return only unique values from a column.
    DataQuery distinct(bool isDistinct) => add("distinct", isDistinct.toString());

    /// Sets the number of "levels" in the hierarchy of related objects to include into the response.
    DataQuery relationsDepth(int depth) => add("relationsDepth", depth.toString());

    /// Sets the number of related objects returned in the response.
    DataQuery relationsPageSize(int p_size) => add("relationsPageSize", p_size.toString());

    /// Sets the name of the columns to group the results by.
    DataQuery groupBy(string agFunction) => add("groupBy", agFunction);

    /// Requests the server to exclude named properties from the response.
    DataQuery excludeProps(List<string> properties) => add("excludeProps", properties.join(","));
}
