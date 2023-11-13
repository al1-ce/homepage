import "dqext.dart";
import "backendless.dart" as bk;
import "types.dart";
import "cookies.dart";

import "package:http/http.dart" as http;
import "dart:convert" show utf8, jsonDecode;
import "package:dquery/dquery.dart" show $, ElementQuery, QueryEvent;
import "dart:html" show Element, Event, window, MouseEvent, InputElement, TextAreaElement;
import "dart:js" as js;

string __currentNoteId = "";
int __currentNoteInd = 0;

Future<void> main() async {
    setPageTo(0);
    bk.initApp("modernthought");
    // Project on home
    // addGithubProjects();
    // Notes on home
    addBackendlessNotes();
    // Link, proj, tool, docs pages
    addBackendlessLinks();
    // Todos
    addBackendlessTodos();

    ElementQuery sel = $(".c-page-sel");
    List<Element> selButtons = sel.toList();
    for (int i = 0; i < selButtons.length; ++i) {
        selButtons[i].addEventListener("click", (Event e) { setPageTo(i); });
    }

    // addConfig("Test", "test__test1", (b) {}, false);
    // addConfig("Test2", "test__test2", (b) {}, true);
    // addConfig("Test3", "test__test3", (b) {});

    $("#bk-login").on("click", (e) async {
        string? uname = ($("#bk-uname").first as InputElement).value;
        string? passw = ($("#bk-passw").first as InputElement).value;
        if (passw != null && uname != null) { if (passw != "" && uname != "") {
                await bk.UserService.login(uname, passw, stayLoggedFor:30);
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

    $("#newtask").on("click", (e) async {
        string? prompt = js.context.callMethod("prompt", ["Input new issue"]);
        if (prompt == null || prompt == "") return;
        JSON j = await bk.Data.add("todo", [{"name": prompt, "status": "todo"}]);
        addTodo(prompt, "todo", j["jsarr"][0]);
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
            await bk.Data.delete("notes", __currentNoteId);
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
                JSON j = await bk.Data.add("notes", [{
                    "content": ta.value,
                    "type": ia.value
                }]);
                DateTime _created = DateTime.now();
                string _date = monthShort(_created.month) + " " + _created.day.toString() +
                       ", " + _created.year.toString();

                addNote(ta.value as string, _date, ia.value as string, j["jsarr"][0]);
            }
        } else {
            // updating old note
            if (ta.value != "") {
                await bk.Data.update("notes", __currentNoteId, {
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
    if (page == 1) $("#c-page-work").show();
    if (page == 2) $("#c-page-tool").show();
    if (page == 3) $("#c-page-docs").show();
    if (page == 4) $("#c-page-link").show();
    // if (page == 5) $("#c-page-note").show();
    if (page == 5) $("#c-page-conf").show();
}

/*
    table: notes
    fields:
        content - string 500
        type - string 250
    table: links
    fields:
        category - string 250
        href - string 250
        name - string 250
        priority - int
    table: todo
        name - string 250
        status - string 250 (todo, doing, complete)
*/

Future<void> addBackendlessNotes() async {
    JSON j = await bk.Data.find("notes", bk.DataQuery().pageSize(100).sortBy(["created"]));
    j["jsarr"].forEach((obj) {
        DateTime _created = DateTime.fromMillisecondsSinceEpoch(obj["created"]);
        string _date = monthShort(_created.month) + " " + _created.day.toString() +
                       ", " + _created.year.toString();
        addNote(obj["content"], _date, obj["type"], obj["objectId"]);
    });
}

Future<void> addBackendlessLinks() async {
    $("c-links-work").children().detach();
    $("c-links-tool").children().detach();
    $("c-links-docs").children().detach();
    $("c-page-link").children().detach();

    JSON j = await bk.Data.find("links", bk.DataQuery().pageSize(100));
    j["jsarr"].forEach((obj) {
        addLinkTo(obj["name"], obj["href"], obj["category"], obj["objectId"]);
    });
}

int __link_id = 0;

void addLinkTo(string name, string href, string whereid, string oid) {
    string escWhereid = whereid.replaceAll(" ", "-");
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
        <div id="c-link-$__link_id" class="c-link">
            $name
        </div>
    """.parseHTML());

    int linkID = __link_id;

    $("#c-link-$linkID").on("mouseup", (QueryEvent e) {
        if (e.button == 0) window.location.href = href;
        if (e.button == 1) js.context.callMethod("open", [href]);
        if (e.button == 2); // TODO: edit
    });

    ++__link_id;
}

int __todo_id = 0;

Future<void> addBackendlessTodos() async {
    JSON j = await bk.Data.find("todo", bk.DataQuery().pageSize(100).sortBy(["created"]));
    j["jsarr"].forEach((obj) { addTodo(obj["name"], obj["status"], obj["objectId"]); });
}

void addTodo(string name, string status, string oid) {
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
                bk.Data.update("todo", oid, {"status": "todo"});
                status = "todo";
            } else {
                bk.Data.update("todo", oid, {"status": "done"});
                status = "done";
            }
        }
        if (e.button == 1) { // doing
            bk.Data.update("todo", oid, {"status": "doing"});
            status = "doing";

        }
        if (e.button == 2) { // delete
            if (!window.confirm("Delete task?")) return;
            bk.Data.delete("todo", oid);
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
    $(".c-notes").prepend("""
        <div class="c-notes-note" id="c-notes-note-$__note_id">
            <div class="c-notes-note-text">$name</div>
            <div class="c-notes-note-date">$date</div>
            <div class="c-notes-note-type">$type</div>
        </div>
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
    buttonCallback(new Event(""), true);

    ++__config_id;
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
