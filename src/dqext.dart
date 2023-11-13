/// Extensions for DQuery
library sily.dqext;

import "dart:html" show Element, NodeValidator, NodeValidatorBuilder, UriPolicy;

import "package:dquery/dquery.dart" show $, ElementQuery, QueryEvent, $window;

import "types.dart";

import 'dart:collection' show Maps;
import 'dart:js';


/// Map of mouseover states for IFrames
Map<ElementQuery, bool> _handlerList = new Map<ElementQuery, bool>();
/// Focus retriever element
ElementQuery? _focusRetriever;

extension FrameTracker on ElementQuery {
    /// Sets callback for when IFrame is clicked
    void iframeTracker(void Function() onClick) {
        this.on("mouseover", (QueryEvent e) {
            _handlerList[this] = true;
        });

        this.on("mouseout", (QueryEvent e) {
            _handlerList[this] = false;
            _focusRetriever?.focus();
        });

        $window().on("blur", (QueryEvent e) {
            if (_handlerList[this] == true) {
                onClick();
            }
        });

        if (_focusRetriever == null) {
            // Element focusHolder = new Element.tag("div");
            // Element focusRetriever = new Element.tag("input");
            //
            // focusHolder.setAttribute("style", "position:fixed; top:0; left:0; overflow:hidden;");
            // focusRetriever.setAttribute("style", "position:absolute; left:-300px;");
            // focusRetriever.setAttribute("type", "text");
            // focusRetriever.setAttribute("value", "");
            // focusRetriever.setAttribute("id", "focus_retriever");
            // focusRetriever.setAttribute("readonly", "true");

            // focusHolder.append(focusRetriever);
            Element focusHolder = parse(
                '<div style="position:fixed; top:0; left:0; overflow:hidden;">'
                '<input style="position:absolute; left:-300px;" type="text" value="" id="focus_retriever" readonly="true" />'
                '</div>');
            $("body").append(focusHolder);
            _focusRetriever = $("#focus_retriever");
        }
        
        _handlerList[this] = false;
    }
}

extension Focus on ElementQuery {
    /// Focuses element
    void focus() {
        this.forEach((Element e) => e.focus());
    }
}

extension MapAttr on ElementQuery {
    /// Sets css values with map
    void cssMap(Map<string, string> m) {
        m.forEach((string key, string val) {
            this.css(key, val);
        });
    }

    /// Sets attributes with map
    void attr(Map<string, Object> m) {
        m.forEach((string key, Object val) {
            this.forEach((Element e) => e.setAttribute(key, val));
        });
    }
}

extension ElementSize on Element {
    /// Returns element size calculated without padding
    int get width {
        var paddingLeft = this.style.paddingLeft.replaceAll('px', '');
        var paddingRight = this.style.paddingRight.replaceAll('px', '');

        paddingLeft = paddingLeft == "" ? "0" : paddingLeft;
        paddingRight = paddingRight == "" ? "0" : paddingRight;

        return this.clientWidth - int.parse(paddingLeft) - int.parse(paddingRight);
    }

    /// Returns element size calculated without padding
    int get height {
        var paddingTop = this.style.paddingTop.replaceAll('px', '');
        var paddingBottom = this.style.paddingBottom.replaceAll('px', '');

        paddingTop = paddingTop == "" ? "0" : paddingTop;
        paddingBottom = paddingBottom == "" ? "0" : paddingBottom;

        return this.clientHeight - int.parse(paddingBottom) - int.parse(paddingTop);
    }
    /// Returns element position calculated without padding
    int get left {
        var paddingLeft = this.style.paddingLeft.replaceAll('px', '');

        paddingLeft = paddingLeft == "" ? "0" : paddingLeft;

        return this.offsetLeft - int.parse(paddingLeft);
    }

    /// Returns element position calculated without padding
    int get top {
        var paddingTop = this.style.paddingTop.replaceAll('px', '');

        paddingTop = paddingTop == "" ? "0" : paddingTop;

        return this.offsetTop - int.parse(paddingTop);
    }
}

class DefaultUriPolicy implements UriPolicy {
  DefaultUriPolicy();

  bool allowsUri(String uri) {
    // Return true/false based on uri comparison
    return true;
  }
}

class NodeValidatorAllowAll implements NodeValidator {
    @override
    bool allowsAttribute(Element element, String attributeName, String value) {
       return true;
    }

    @override
    bool allowsElement(Element element) {
      return true;
    }
}
//
// NodeValidator _nodeValidator = new NodeValidatorBuilder()
//     ..allowSvg()
//     ..allowHtml5()
//     ..allowImages()
//     ..allowTemplating()
//     ..allowTextElements()
//     ..allowNavigation()
//     ..allowInlineStyles()
//     ..allowElement("iframe", attributes: ["src"], uriPolicy: new DefaultUriPolicy())
//     ..allowElement('a', attributes: ['href'], uriPolicy: new DefaultUriPolicy())
//     ..allowElement("img", attributes: ["src"], uriPolicy: new DefaultUriPolicy())
//     ..allowElement("link", attributes:["href"], uriPolicy: new DefaultUriPolicy());
//

/// Parses html with forgiving node validator
Element parse(string html) {
    return new Element.html(html, validator: NodeValidatorAllowAll());
}

extension ParseHTML on string {
    /// Parses html with forgiving node validator
    Element parseHTML() {
        return new Element.html(this, validator: NodeValidatorAllowAll());
    }
}

