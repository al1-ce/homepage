import "dart:convert" show utf8, jsonDecode, jsonEncode;
import "dart:html" show Element, Event, window, MouseEvent, InputElement, TextAreaElement, document;
import "dart:js" as js;
import "dart:js_interop" show JSArray;

import "package:http/http.dart" as http;
import "package:dquery/dquery.dart" show $, ElementQuery, QueryEvent;

import "lib/dqext.dart";
import "lib/backendless.dart" as bk show UserService, DataQuery;
import "lib/types.dart";
import "lib/cookies.dart";
import "lib/saltcorn.dart" as saltcorn;

import "storage.dart" as storage;

string __currentNoteId = "";
int __currentNoteInd = 0;
string __currentToolId = "";

bool isUserUsingMobile() {
    RegExp re = RegExp(r"Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini");

    // User agent string method
    bool isMobile = re.hasMatch(window.navigator.userAgent);

    // Screen resolution method
    if (!isMobile) {
        int screenWidth = window.screen?.width as int;
        int screenHeight = window.screen?.height as int;
        isMobile = (screenWidth < 768 || screenHeight < 768);
    }

    return isMobile;
}

Future<void> main() async {
    setPageTo(0);
    storage.init(getOrInitCookie("use_local_storage", "false") == "true");

    if (isUserUsingMobile()) {
        $("#mobile-style").first.innerHtml = "body{font-size:0.7em;}#c-title{font-size:1.3em}";
    } else {
        $("body").addClass("squeeze");
    }

    ElementQuery sel = $(".c-page-sel");
    List<Element> selButtons = sel.toList();
    for (int i = 0; i < selButtons.length; ++i) {
        selButtons[i].addEventListener("click", (Event e) { setPageTo(i); });
    }

    // addConfig("Test", "test__test1", (b) {}, false);
    // addConfig("Test2", "test__test2", (b) {}, true);
    // addConfig("Use local storage", "use_local_storage", (b) {
    //     if (b == true) $("#bk-login-form").hide();
    //     if (b == true) $("#bk-logout-form").hide();
    //     if (b != storage.isUsingLocal()) window.location.reload();
    // });

    List<Element> soptions = $("#storage-options").children();
    soptions[0].addEventListener("click", (Event e) {
        setCookie("use_local_storage", "true");
        window.location.reload();
    });
    soptions[1].addEventListener("click", (Event e) {
        setCookie("use_local_storage", "false");
        window.location.reload();
    });

    if (storage.isUsingLocal()) {
        setupLocalDB();
    } else {
        setupBackendlessDB();
    }

    setupSaltcornDB();
}

Future<void> setupLocalDB() async {
    $("#login-header").hide();
    $("#login-separator").hide();
    $("#bk-login-form").hide();
    $("#bk-logout-form").hide();

    setupStorageDB();
}

Future<void> setupBackendlessDB() async {
    $("#bk-login").on("click", (e) async {
        string? uname = ($("#bk-uname").first as InputElement).value;
        string? passw = ($("#bk-passw").first as InputElement).value;
        if (passw != null && uname != null) { if (passw != "" && uname != "") {
                JSON j = await bk.UserService.login(uname, passw, stayLoggedFor:30);
                if (j.containsKey("errorData")) print(j);
        } }
        if (await bk.UserService.isValidLogin()) {
            $("#bk-login-form").hide();
            $("#bk-logout-form").show();
            window.location.reload();
        }
    });

    $("#bk-logout").on("click", (e) async {
        if (window.confirm("Do you want to log out?") == false) return;
        await bk.UserService.logout();
        $("#bk-login-form").show();
        $("#bk-logout-form").hide();
        window.location.reload();
    });

    if (await bk.UserService.isValidLogin()) {
        $("#bk-login-form").hide();
        $("#bk-logout-form").show();
    } else {
        $("#bk-login-form").show();
        $("#bk-logout-form").hide();
        $("#c-title").addClass("unlogged");
    }

    if ((await bk.UserService.isValidLogin()) == true) setupStorageDB();
}

Future<void> setupStorageDB() async {
    // Project on home
    // addGithubProjects();
    // Notes on home
    addBackendlessNotes();
    // Link, proj, tool, docs pages
    addBackendlessLinks();
    // Todos
    addBackendlessTodos();


    $("#newtask").on("click", (e) async {
        string? prompt = js.context.callMethod("prompt", ["Input new task"]);
        if (prompt == null || prompt == "") return;
        string _id = await storage.add("todo", {"name": prompt, "status": "todo"});
        addTodo(prompt, "todo", _id);
    });

    $("#newnote").on("click", (e) async {
        __currentNoteId = "";
        $("#newnote-gui").show();
        $("#newnote-header-text").first.innerText = "new";
        ($("#newnote-type").first as InputElement).value = "note";
        ($("#newnote-text").first as TextAreaElement).value = "";

    });

    $("#newnote-cancel").on("click", (e) async {
        __currentNoteId = "";
        $("#newnote-gui").hide();
    });

    $("#newnote-delete").on("click", (e) async {
        if (__currentNoteId != "") {
            if (!window.confirm("Delete note?")) return;
            await storage.delete("notes", __currentNoteId);
            $("#c-notes-note-$__currentNoteInd").detach();
        }

        __currentNoteId = "";
        $("#newnote-gui").hide();
    });

    $("#newnote-create").on("click", (e) async {
        TextAreaElement ta = $("#newnote-text").first as TextAreaElement;
        InputElement ia = $("#newnote-type").first as InputElement;
        if (__currentNoteId == "") {
            // creating new note
            if (ta.value != "") {
                string _id = await storage.add("notes", {
                    "content": ta.value,
                    "type": ia.value
                });
                DateTime _created = DateTime.now();
                string _date = monthShort(_created.month) + " " + _created.day.toString() +
                       ", " + _created.year.toString();

                addNote(ta.value as string, _date, ia.value as string, _id);
            }
        } else {
            // updating old note
            if (ta.value != "") {
                await storage.update("notes", __currentNoteId, {
                    "content": ta.value,
                    "type": ia.value
                });
                $("#c-notes-note-$__currentNoteInd").children()[0].innerText = ta.value as string;
                $("#c-notes-note-$__currentNoteInd").children()[2].innerText = ia.value as string;
            }

        }

        __currentNoteId = "";
        $("#newnote-gui").hide();
    });

    $("#links-close").on("click", (e) {
        window.location.reload();
    });

    $("#edit-links").on("click", (e) {
        $("#links-gui").show();
    });
}

Future<void> setupSaltcornDB() async {
    JSON data;
    try {
        data = await saltcorn.data("tools");
    } on Exception {
        print("Failed to locate saltcorn database");
        return;
    }

    print(data);

    if (data.containsKey("error") || !data.containsKey("success")) return;

    $("#pagesel-tools").show();

    $("#tool-addnew").on("click", (QueryEvent e) {
        $("#tool-gui-header-text").first.text = "new";
        __currentToolId = "";
        ($("#tool-edit-name").first as InputElement).value = "";
        ($("#tool-edit-href").first as InputElement).value = "";
        ($("#tool-edit-desc").first as InputElement).value = "";
        ($("#tool-edit-tags").first as InputElement).value = "";
        $("#tool-gui-edit").show();
    });

    $("#tool-gui-cancel").on("click", (QueryEvent e) {
        $("#tool-gui-edit").hide();
    });

    $("#tool-gui-confirm").on("click", (QueryEvent e) async {
        string name = ($("#tool-edit-name").first as InputElement).value as string;
        string href = ($("#tool-edit-href").first as InputElement).value as string;
        string desc = ($("#tool-edit-desc").first as InputElement).value as string;
        string tags = ($("#tool-edit-tags").first as InputElement).value as string;
        if (name == "" || href == "" || desc == "" || tags == "") return;
        if (__currentToolId == "") {
            JSON j = await saltcorn.add("tools", {"name": name, "href": href, "description": desc, "tags": tags});
            if (j.containsKey("success")) {
                addTool(name, desc, href, tags, "tools-el-${j['id']}");
            } else {
                window.alert("Failed to add tool");
            }
        } else {
            JSON j = await saltcorn.update("tools", __currentToolId, {"name": name, "href": href, "description": desc, "tags": tags});
            if (j.containsKey("success")) {
                if (j["success"] == true) {
                    $("#tools-el-${__currentToolId}").first.remove();
                    addTool(name, desc, href, tags, "tools-el-${__currentToolId}");
                }
            }
        }
        $("#tool-gui-edit").hide();
    });

    $(".c-tools-list").children().forEach((Element e) => e.remove());
    $("#tool-searchbar").first.replaceWith($("#tool-searchbar").first.clone(false));

    var fields = data["success"];
    fields.sort((a, b) => a["name"].compareTo(b["name"]) as int);

    for (int i = 0; i < fields.length; ++i) {
        JSON field = fields[i] as JSON;
        string id = "tools-el-${field["id"]}";
        addTool(field["name"], field["description"], field["href"], field["tags"], id);

        $("#tool-searchbar").on("input", (QueryEvent e) {
            string text = ($("#tool-searchbar").first as InputElement).value as string;
            if (
                (field["name"] as string).contains(text) ||
                (field["tags"] as string).contains(text) ||
                (field["description"] as string).contains(text)
                ) {
                $("#$id").show();
            } else {
                $("#$id").hide();
            }
        });

        $("#c-tool-edit-$id").on("click", (QueryEvent e) {
            $("#tool-gui-header-text").first.text = "edit";
            __currentToolId = '${field["id"]}';
            ($("#tool-edit-name").first as InputElement).value = field["name"];
            ($("#tool-edit-href").first as InputElement).value = field["href"];
            ($("#tool-edit-desc").first as InputElement).value = field["description"];
            ($("#tool-edit-tags").first as InputElement).value = field["tags"];
            $("#tool-gui-edit").show();
        });

        $("#c-tool-del-$id").on("click", (QueryEvent e) {
            if (window.confirm("Do you want to delete tool '${field["name"]}'?") == false) return;
            saltcorn.delete("tools", '${field["id"]}');
            $("#$id").first.remove();
        });

    }
}

void addTool(string name, string desc, string href, string p_tags, string id) {
    List<string> taglist = p_tags.split(',');
    string tags = "";
    for (int j = 0; j < taglist.length; ++j) {
        string tag = taglist[j];
        tags += """ <div class="tool-tag" data="$tag">$tag</div> """;
    }
    $(".c-tools-list").append(parse("""
    <div class="c-tool" id="$id">
        <div class="c-tool-name"><a href="$href">$name</a></div>
        <div class="c-tool-desc">$desc</div>
        <div class="c-tool-tags">$tags</div>
        <button class="c-tool-edit button-no-style" id="c-tool-edit-$id"><img src="assets/icons/edit_square.svg"/></button>
        <button class="c-tool-del button-no-style" id="c-tool-del-$id"><img src="assets/icons/close.svg"/></button>
    </div>
    """));
}

void setPageTo(int page) {
    $("#c-page-home").hide();
    $("#c-page-work").hide();
    $("#c-page-tool").hide();
    $("#c-page-docs").hide();
    $("#c-page-link").hide();
    // $("#c-page-note").hide();
    $("#c-page-conf").hide();
    if (page == 0) $("#c-page-home").show();
    // if (page == 1) $("#c-page-work").show();
    if (page == 2) $("#c-page-tool").show();
    // if (page == 3) $("#c-page-docs").show();
    if (page == 1) $("#c-page-link").show();
    // if (page == 5) $("#c-page-note").show();
    if (page == 3) $("#c-page-conf").show();
}

/*
    table: notes
    fields:
        content - string 500
        type - string 250

    table: links
    fields:
        name - string 250
        href - string 250
        category - string 250
        priority - int

    table: todo
        name - string 250
        status - string 250 (todo, doing, complete)
*/

Future<void> addBackendlessNotes() async {
    JSON j = await storage.get("notes", bk.DataQuery().pageSize(100).sortBy(["created"]));
    j["jsarr"].forEach((obj) {
        DateTime _created = DateTime.fromMillisecondsSinceEpoch(obj["created"]);
        string _date = monthShort(_created.month) + " " + _created.day.toString() +
                       ", " + _created.year.toString();
        addNote(obj["content"], _date, obj["type"], obj["objectId"]);
    });
}

Future<void> addBackendlessLinks() async {
    addLinkTo("", "", "", 0, "");
    JSON j = await storage.get("links", bk.DataQuery().pageSize(100).sortBy(["category", "priority"]));
    j["jsarr"].reversed.forEach((obj) {
        addLinkTo(obj["name"], obj["href"], obj["category"], obj["priority"], obj["objectId"]);
    });
}

int __link_id = 0;

void addLinkTo(string name, string href, string whereid, int priority, string oid) {
    name = fixStringHTML(name);
    string escWhereid = whereid.replaceAll(" ", "-");
    escWhereid = fixStringHTML(escWhereid);
    int linkID = oid == "" ? -1 : __link_id;

    if (href.contains("<") || href.contains(">")) {
        window.alert("Link contains invalid symbols!");
        return;
    }

    if (oid != "") {
        ElementQuery q = $(".c-links-$escWhereid");

        if (q.length == 0) {
            $("#c-page-link").append("""
                <div class="c-links-$escWhereid c-links-list">
                    <div class="c-links-title">$whereid</div>
                </div>
            """.parseHTML());

            q = $(".c-links-$escWhereid");
        }


        q.append("""
            <a id="c-link-$__link_id" class="c-link button-no-style">
                $name
            </a>
        """.parseHTML());

        $("#c-link-$linkID").on("mouseup", (QueryEvent e) {
            if (e.button == 0) window.location.href = href;
            if (e.button == 1) js.context.callMethod("open", [href]);
            if (e.button == 2); // TODO: edit
        });

        ++__link_id;
    }

    $("#links-container").append("""
        <div class="links-container-link" id="links-container-$linkID">
            <input id="links-name-$linkID" type="text" value="$name" placeholder="name" />
            <input id="links-href-$linkID" type="text" value="$href" placeholder="url" />
            <input id="links-cate-$linkID" type="text" value="$whereid" class="icat" placeholder="category" />
            <input id="links-prio-$linkID" type="number" value="$priority" class="inum" />
            <button id="link-delete-$linkID" class="button-no-style">delete</button>
            <button id="link-submit-$linkID" class="button-no-style">submit</button>
        </div>
    """.parseHTML());

    $("#link-submit-$linkID").on("click", (e) async {
        if (oid == "") { // create new
            await storage.add("links", {
                "name": ($("#links-name-$linkID").first as InputElement).value,
                "href": ($("#links-href-$linkID").first as InputElement).value,
                "category": ($("#links-cate-$linkID").first as InputElement).value,
                "priority": int.parse(($("#links-prio-$linkID").first as InputElement).value as string),
            });
            ($("#links-name-$linkID").first as InputElement).value = "";
            ($("#links-href-$linkID").first as InputElement).value = "";
            ($("#links-cate-$linkID").first as InputElement).value = "";
            ($("#links-prio-$linkID").first as InputElement).value = "0";
        } else {
            await storage.update("links", oid, {
                "name": ($("#links-name-$linkID").first as InputElement).value,
                "href": ($("#links-href-$linkID").first as InputElement).value,
                "category": ($("#links-cate-$linkID").first as InputElement).value,
                "priority": int.parse(($("#links-prio-$linkID").first as InputElement).value as string),
            });
        }
    });

    $("#link-delete-$linkID").on("click", (e) async {
        if (oid != "" && window.confirm("delete link?")) {
            await storage.delete("links", oid);
            $("#links-container-$linkID").detach();
        }
    });

}

int __todo_id = 0;

Future<void> addBackendlessTodos() async {
    JSON j = await storage.get("todo", bk.DataQuery().pageSize(100).sortBy(["created"]));
    j["jsarr"].forEach((obj) { addTodo(obj["name"], obj["status"], obj["objectId"]); });
}

void addTodo(string name, string status, string oid) {
    name = fixStringHTML(name);

    string icon = "check_box_outline";
    string addStatus = "";
    if (status == "doing") {
        icon = "check_box_line";
        addStatus = "c-task-doing";
    }
    if (status == "done") {
        icon = "check_box_complete";
        addStatus = "c-task-done";
    }

    $(".c-tasks").prepend("""
        <button id="c-task-$__todo_id" class="c-task $addStatus">
            <img id="c-task-$__todo_id-img" src="assets/icons/$icon.svg" />
            <div>$name</div>
        </button>
    """.parseHTML());

    int todoID = __todo_id;

    $("#c-task-$__todo_id").on("mouseup", (QueryEvent e) {
        if (e.button == 0) { // complete
            if (status == "done") {
                storage.update("todo", oid, {"status": "todo"});
                status = "todo";
            } else {
                storage.update("todo", oid, {"status": "done"});
                status = "done";
            }
        }
        if (e.button == 1) { // doing
            storage.update("todo", oid, {"status": "doing"});
            status = "doing";

        }
        if (e.button == 2) { // delete
            if (!window.confirm("Delete task?")) return;
            storage.delete("todo", oid);
            $("#c-task-$todoID").detach();
        }
        if (status == "doing") {
            icon = "check_box_line";
            $("#c-task-$todoID").addClass("c-task-doing");
            $("#c-task-$todoID").removeClass("c-task-done");
        } else
        if (status == "done") {
            icon = "check_box_complete";
            $("#c-task-$todoID").removeClass("c-task-doing");
            $("#c-task-$todoID").addClass("c-task-done");
        } else {
            icon = "check_box_outline";
            $("#c-task-$todoID").removeClass("c-task-doing");
            $("#c-task-$todoID").removeClass("c-task-done");
        }

        $("#c-task-$todoID-img").attr({"src": "assets/icons/$icon.svg"});

        e.preventDefault();
    });
    ++__todo_id;
}

int __note_id = 0;

void addNote(string name, string date, string type, string oid) {
    // string og_name = name;
    name = fixStringHTML(name);
    date = fixStringHTML(date);
    type = fixStringHTML(type);

    $(".c-notes").prepend("""
        <button class="c-notes-note button-no-style" id="c-notes-note-$__note_id">
            <div class="c-notes-note-text">$name</div>
            <div class="c-notes-note-date">$date</div>
            <div class="c-notes-note-type" note-class="$type">$type</div>
        </button>
    """.parseHTML());

    int noteID = __note_id;
    $("#c-notes-note-$__note_id").on("click", (e) {
        __currentNoteId = oid;
        __currentNoteInd = noteID;
        $("#newnote-gui").show();
        $("#newnote-header-text").first.innerText = "edit";
        ($("#newnote-type").first as InputElement).value =
                ($("#c-notes-note-$noteID").children()[2]).innerText;
        ($("#newnote-text").first as TextAreaElement).value =
                ($("#c-notes-note-$noteID").children()[0]).innerText;
    });

    ++__note_id;
}

int __project_id = 0;

void addProject(string title, string description, string href) {
    $(".c-projects").prepend("""
        <button class="c-proj-project c-proj-project-$__project_id">
            <div class="c-proj-title">$title</div>
            <div class="c-proj-desc">$description</div>
        </button>
    """.parseHTML());

    $(".c-proj-project-$__project_id").on("mouseup", (QueryEvent e) {
        if (e.button == 0) window.location.href = href;
        if (e.button == 1) js.context.callMethod("open", [href]);
        e.preventDefault();
    });

    ++__project_id;
}

int __config_id = 0;

void addConfig(string name, string cookieName, Function(bool) callback, [bool initState = true]) {
    string _id = "c-page-conf-id-$__config_id";
    $("#c-page-conf").append("""
        <button id="$_id">
            <img id="$_id-img" />
            <div>$name</div>
        </button>
    """.parseHTML());

    getOrInitCookie(cookieName, initState ? "true" : "false");

    void buttonCallback(Event e, [bool isFirst = false]) {
        bool state = getCookie(cookieName) == "true";
        if  (!isFirst) {
            state = !state;
            setCookie(cookieName, state ? "true" : "false");
        }
        if (state) {
            $("#$_id-img").attr({"src": "assets/icons/check_box_complete.svg"});
        } else {
            $("#$_id-img").attr({"src": "assets/icons/check_box_outline.svg"});
        }
        callback(state);
    }

    $("#$_id").on("click", buttonCallback);

    // required to set correct graphics and
    // do initial callback
    buttonCallback(new Event(""), true);

    ++__config_id;
}

string fixStringHTML(string s) {
    string o = s;
    o = o.replaceAll("<", "&lt;");
    o = o.replaceAll(">", "&gt;");
    o = o.replaceAll("/", "&#47;");
    o = o.replaceAll("\"", "&apos;");
    o = o.replaceAll("\'", "&quot;");
    return o;
}

string monthShort(int m) {
    switch (m) {
        case 1 : return "jan";
        case 2 : return "feb";
        case 3 : return "mar";
        case 4 : return "apr";
        case 5 : return "may";
        case 6 : return "jun";
        case 7 : return "jul";
        case 8 : return "aug";
        case 9 : return "sep";
        case 10: return "oct";
        case 11: return "nov";
        case 12: return "dec";
    }
    return "jan";
}
