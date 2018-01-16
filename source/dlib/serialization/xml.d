/*
Copyright (c) 2015-2017 Timur Gafarov

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module dlib.serialization.xml;

import std.stdio;
import std.conv;
import dlib.core.memory;
import dlib.core.compound;
import dlib.container.array;
import dlib.container.dict;
import dlib.container.stack;
import dlib.text.slicelexer;
import dlib.text.utils;

/*
 * GC-free parser for a subset of XML.
 * Has the following limitations:
 * - supports only ASCII and UTF-8 encodings
 * - doesn't support DOCTYPE and some other special tags
 */

string[] xmlDelims =
[
    "<", ">", "</", "/>", "=", "<?", "?>", "\"",
    "<!--", "-->", "<![CDATA[", "]]>",
    "\"", "'", " ", "\n",
];

enum XmlToken
{
    TagOpen,
    TagClose,
    TagName,
    Assignment,
    Quote,
    PropValue
}

string emptyStr;

string appendChar(string s, dchar ch)
{
    char[7] firstByteMark = [0x00, 0x00, 0xC0, 0xE0, 0xF0, 0xF8, 0xFC];

    char[4] chars;
    uint byteMask = 0xBF;
    uint byteMark = 0x80;

    uint bytesToWrite = 0;
    if (ch < 0x80) bytesToWrite = 1;
    else if (ch < 0x800) bytesToWrite = 2;
    else if (ch < 0x10000) bytesToWrite = 3;
    else bytesToWrite = 4;

    char* target = chars.ptr;
    target += bytesToWrite;
    switch (bytesToWrite)
    {
        case 4: *--target = cast(char)((ch | byteMark) & byteMask); ch >>= 6; goto case 3;
        case 3: *--target = cast(char)((ch | byteMark) & byteMask); ch >>= 6; goto case 2;
        case 2: *--target = cast(char)((ch | byteMark) & byteMask); ch >>= 6; goto case 1;
        case 1: *--target = cast(char)(ch | firstByteMark[bytesToWrite]); break;
        default: break;
    }

    return catStr(s, cast(string)chars[0..bytesToWrite]);
}

class XmlNode
{
    XmlNode parent;
    DynamicArray!XmlNode children;
    string name;
    string text;
    Dict!(string, string) properties;

    this(string name, XmlNode parent = null)
    {
        this.name = name;
        this.parent = parent;
        if (parent !is null)
        {
            parent.addChild(this);
        }
        this.properties = New!(Dict!(string, string));
    }

    ~this()
    {
        if (text.length)
            Delete(text);
        if (name.length)
            Delete(name);
        foreach(k, v; properties)
        {
            Delete(k);
            Delete(v);
        }
        Delete(properties);
        foreach(c; children)
        {
            Delete(c);
        }
        children.free();
    }

    XmlNode firstChildByTag(string tag)
    {
        XmlNode res = null;
        foreach(c; children)
        {
            if (c.name == tag)
            {
                res = c;
                break;
            }
        }

        return res;
    }

    void addChild(XmlNode node)
    {
        children.append(node);
    }

    void appendText(dchar c)
    {
        string newText = appendChar(text, c);
        if (text.length)
            Delete(text);
        text = newText;
    }

    string getTextUnmanaged()
    {
        DynamicArray!char res;
        res.append(text);
        foreach(n; children)
        {
            string t = n.getTextUnmanaged();
            if (t.length)
            {
                res.append(t);
                Delete(t);
            }
        }
        string output = immutableCopy(cast(string)res.data);
        res.free();
        return output;
    }

    void printProperties(dstring indent = "")
    {
        if (properties.length)
        {
            foreach(k, v; properties)
                writeln(indent, k, " = ", v);
        }
    }

    // Warning! Causes GC allocation!
    void print(dstring indent = "")
    {
        printProperties(indent);

        foreach(n; children)
        {
            auto nm = n.name;
            if (nm.length)
                writeln(indent, "tag: ", nm);
            else
                writeln(indent, "tag: <anonymous>");

            string txt = n.getTextUnmanaged();
            if (txt.length)
            {
                writeln(indent, "text: ", txt);
                Delete(txt);
            }

            n.print(indent ~ " ");
        }
    }
}

string prop(XmlNode node, string name)
{
    if (name in node.properties)
        return node.properties[name];
    else
        return "";
}

class XmlDocument
{
    XmlNode prolog = null;
    XmlNode root;

    this()
    {
        root = New!XmlNode(emptyStr);
    }

    ~this()
    {
        Delete(root);
        if (prolog)
            Delete(prolog);
    }
}

XmlDocument parseXMLUnmanaged(string text)
{
    XmlDocument doc = New!XmlDocument();
    SliceLexer lex = New!SliceLexer(text, xmlDelims);
    Stack!XmlNode nodeStack;

    nodeStack.push(doc.root);

    XmlToken expect = XmlToken.TagOpen;

    bool tagOpening = false;
    bool xmlPrologDeclaration = false;
    bool comment = false;
    bool cdata = false;
    bool lastCharWasWhitespace = false;

    string tmpPropName;
    DynamicArray!char tmpPropValue;

    bool finished = false;

    bool failed = false;
    void error(string text, string t)
    {
        writefln("XML parse error: %s \"%s\"", text, t);
        failed = true;
    }

    string token;
    while(!finished)
    {
        token = lex.getLexeme();

        //writeln(token);

        if (!token.length)
            break;

        //version(None)
        switch(token)
        {
            case "<![CDATA[":
                if (comment) break;
                cdata = true;
                break;

            case "]]>":
                if (comment) break;
                if (cdata)
                    cdata = false;
                else
                {
                    error("Unexpected token ", token);
                    finished = true;
                }
                break;

            case "<!--":
                if (cdata)
                {
                    XmlNode node = New!XmlNode(emptyStr, nodeStack.top);
                    node.text = immutableCopy(token);
                }
                else
                    comment = true;
                break;

            case "-->":
                if (cdata)
                {
                    XmlNode node = New!XmlNode(emptyStr, nodeStack.top);
                    node.text = immutableCopy(token);
                }
                else if (comment)
                    comment = false;
                else
                {
                    error("Unexpected token ", token);
                    finished = true;
                }
                break;

            case "<":
                if (comment) break;
                if (cdata)
                {
                    XmlNode node = New!XmlNode(emptyStr, nodeStack.top);
                    node.text = immutableCopy(token);
                }
                else if (expect == XmlToken.TagOpen)
                {
                    expect = XmlToken.TagName;
                    tagOpening = true;
                }
                else
                {
                    error("Unexpected token ", token);
                    finished = true;
                }
                break;

            case ">":
                if (comment) break;
                if (cdata)
                {
                    XmlNode node = New!XmlNode(emptyStr, nodeStack.top);
                    node.text = immutableCopy(token);
                }
                else if (expect == XmlToken.TagClose && !xmlPrologDeclaration)
                {
                    expect = XmlToken.TagOpen;
                }
                else
                {
                    error("Unexpected token ", token);
                    finished = true;
                }
                break;

            case "</":
                if (comment) break;
                if (cdata)
                {
                    XmlNode node = New!XmlNode(emptyStr, nodeStack.top);
                    node.text = immutableCopy(token);
                }
                else if (expect == XmlToken.TagOpen)
                {
                    expect = XmlToken.TagName;
                }
                break;

            case "/>":
                if (comment) break;
                if (cdata)
                {
                    XmlNode node = New!XmlNode(emptyStr, nodeStack.top);
                    node.text = immutableCopy(token);
                }
                else if (expect == XmlToken.TagClose && !xmlPrologDeclaration)
                {
                    expect = XmlToken.TagOpen;
                    nodeStack.pop();
                }
                else
                {
                    error("Unexpected token ", token);
                    finished = true;
                }
                break;

            case "<?":
                if (comment) break;
                if (cdata)
                {
                    XmlNode node = New!XmlNode(emptyStr, nodeStack.top);
                    node.text = immutableCopy(token);
                }
                else if (expect == XmlToken.TagOpen)
                {
                    expect = XmlToken.TagName;
                    xmlPrologDeclaration = true;
                    tagOpening = true;
                }
                break;

            case "?>":
                if (comment) break;
                if (cdata)
                {
                    XmlNode node = New!XmlNode(emptyStr, nodeStack.top);
                    node.text = immutableCopy(token);
                }
                else if (expect == XmlToken.TagClose && xmlPrologDeclaration)
                {
                    expect = XmlToken.TagOpen;
                    xmlPrologDeclaration = false;
                    nodeStack.pop();
                }
                break;

            case "=":
                if (comment) break;
                if (cdata)
                {
                    XmlNode node = New!XmlNode(emptyStr, nodeStack.top);
                    node.text = immutableCopy(token);
                }
                else if (expect == XmlToken.Assignment)
                {
                    expect = XmlToken.Quote;
                }
                else if (expect == XmlToken.TagOpen)
                {
                    XmlNode node = New!XmlNode(emptyStr, nodeStack.top);
                    node.text = immutableCopy(token);
                }
                else
                {
                    error("Unexpected token ", token);
                    finished = true;
                }
                break;

            case "\"":
                if (comment) break;
                if (cdata)
                {
                    XmlNode node = New!XmlNode(emptyStr, nodeStack.top);
                    node.text = immutableCopy(token);
                }
                else if (expect == XmlToken.Quote)
                {
                    expect = XmlToken.PropValue;
                }
                else if (expect == XmlToken.PropValue)
                {
                    expect = XmlToken.TagClose;
                    nodeStack.top.properties[immutableCopy(tmpPropName)] = immutableCopy(cast(string)tmpPropValue.data);
                    tmpPropValue.free();
                }
                else
                {
                    error("Unexpected token ", token);
                    finished = true;
                }
                break;

            default:
                if (comment) break;
                if (cdata)
                {
                    XmlNode node = New!XmlNode(emptyStr, nodeStack.top);
                    node.text = immutableCopy(token);
                    break;
                }

                if (token != " " && token != "\n")
                    lastCharWasWhitespace = false;

                if (token == " " || token == "\n")
                {
                    if (expect == XmlToken.TagOpen)
                    {
                        if (nodeStack.top.children.length)
                        {
                            if (nodeStack.top.children.data[$-1].text == " ")
                                break;
                        }
                        else if (!nodeStack.top.text.length)
                            break;
                        else if (nodeStack.top.text[$-1] == ' ')
                            break;

                        XmlNode node = New!XmlNode(emptyStr, nodeStack.top);
                        node.text = immutableCopy(" ");
                    }
                    else if (expect == XmlToken.PropValue)
                    {
                        if (!lastCharWasWhitespace)
                        {
                            tmpPropValue.append(' ');
                            lastCharWasWhitespace = true;
                        }
                    }
                }
                else if (expect == XmlToken.TagName)
                {
                    expect = XmlToken.TagClose;
                    if (xmlPrologDeclaration)
                    {
                        if (tagOpening)
                        {
                            if (doc.prolog is null)
                            {
                                if (token == "xml")
                                {
                                    doc.prolog = New!XmlNode(immutableCopy(token));
                                    nodeStack.push(doc.prolog);
                                    tagOpening = false;
                                }
                                else
                                {
                                    error("Illegal XML prolog", emptyStr);
                                    finished = true;
                                }
                            }
                            else
                            {
                                error("More than one XML prolog is not allowed", emptyStr);
                                finished = true;
                            }
                        }
                        else
                        {
                            nodeStack.pop();
                        }
                    }
                    else if (tagOpening)
                    {
                        XmlNode node = New!XmlNode(immutableCopy(token), nodeStack.top);
                        nodeStack.push(node);
                        tagOpening = false;
                    }
                    else
                    {
                        if (token == nodeStack.top.name)
                            nodeStack.pop();
                        else
                        {
                            error("Mismatched tag", emptyStr);
                            finished = true;
                        }
                    }
                }
                else if (expect == XmlToken.TagOpen)
                {
                    XmlNode node = New!XmlNode(emptyStr, nodeStack.top);
                    if (token[0] == '&')
                    {
                        if (token[1] == '#' && token.length > 2)
                        {
                            dchar c = '?';
                            if (token[2] == 'x')
                            {
                                int code = hexCharacterCode(token[3..$]);
                                if (code == -1)
                                {
                                    error("Failed to parse character reference ", token);
                                    finished = true;
                                }
                                else
                                    c = cast(dchar)code;
                            }
                            else
                                c = cast(dchar)to!uint(token[2..$-1]);

                            node.appendText(c);
                        }
                        else
                            node.text = immutableCopy(token);
                    }
                    else
                        node.text = immutableCopy(token);
                }
                else if (expect == XmlToken.TagClose)
                {
                    expect = XmlToken.Assignment;

                    if (tmpPropName.length)
                        Delete(tmpPropName);
                    tmpPropName = immutableCopy(token);
                }
                else if (expect == XmlToken.PropValue)
                {
                    tmpPropValue.append(token);
                }
                else
                {
                    error("Unexpected token ", token);
                    finished = true;
                }
                break;
        }
    }

    if (tmpPropName.length)
        Delete(tmpPropName);
    tmpPropValue.free();

    nodeStack.free();
    Delete(lex);

    if (failed)
    {
        Delete(doc);
        doc = null;
    }

    return doc;
}

int hexCharacterCode(string input)
{
    int res;
    foreach(c; input)
    {
        switch(c)
        {
            case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9':
                res = res * 0x10 | c - '0';
                break;
            case 'a', 'b', 'c', 'd', 'e', 'f':
                res = res * 0x10 | c - 'a' + 0xA;
                break;
            case 'A', 'B', 'C', 'D', 'E', 'F':
                res = res * 0x10 | c - 'A' + 0xA;
                break;
            case ';':
                return res;
            default:
                return -1;
        }
    }
    return res;
}
