library sily.cookies;

import "dart:html";

import "types.dart";

void setCookie(string cname, string cvalue, [int exdays = 365]) {
    string expires = "max-age=" + (exdays * 24 * 60 * 60).toString();

    document.cookie = cname + "=" + cvalue + "\;" + expires + "\;path=/";
}

string getCookie(string cname) {
    string name = cname + "=";
    string decodedCookie = Uri.decodeComponent(document.cookie as string);
    List<string> ca = decodedCookie.split("\;");

    for (int i = 0; i < ca.length; ++i) {
        string c = ca[i];
        while (c.length > 0 && c[0] == " ") {
            c = c.substring(1);
        }
        if (c.indexOf(name) == 0) {
            return c.substring(name.length, c.length);
        }
    }

    return "";
}

void delCookie(string cname) {
    document.cookie = cname + "=\; expires=Thu, 01 Jan 1970 00:00:00 UTC\; path=/\;";
}

string getOrInitCookie(string cname, cdef, [int exdays = 365]) {
    string c = getCookie(cname);

    if (c == "") {
        c = cdef;
        setCookie(cname, c, exdays);
    }

    return c;
}


Map<string, string> getUrlVars() {
    string href = window.location.href;
    Map<string, string> vars = new Map<string, string>();
    List<string> hashes = href.substring(href.indexOf("?") + 1).split("#")[0].split("&");
    for (int i = 0; i < hashes.length; ++i) {
        List<string> hash = hashes[i].split("=");
        string _hash = hash[0];
        vars[_hash] = hash[1];
    }
    return vars;
}
