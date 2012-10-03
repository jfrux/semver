component name="semver" extends="foundry.core" {
  public any function init() {
    // See http://semver.org/
    // This implementation is a *hair* less strict in that it allows
    // v1.2.3 things, and also tags that don't begin with a char.
    variables._ = require("util").init();
    variables.console = new foundry.core.console();
    variables.ver = "\s*[v=]*\s*([0-9]+)"        // major
                   & "\.([0-9]+)"                  // minor
                   & "\.([0-9]+)"                  // patch
                   & "(-[0-9]+-?)?"                 // build
                   & "([a-zA-Z-+][a-zA-Z0-9-\.:]*)?" // tag
    variables.exprComparator = "^((<|>)?=?)\s*("&ver&")$|^$";
    variables.xRangePlain = "[v=]*([0-9]+|x|X|\*)"
                & "(?:\.([0-9]+|x|X|\*)"
                & "(?:\.([0-9]+|x|X|\*)"
                & "([a-zA-Z-][a-zA-Z0-9-\.:]*)?)?)?";
    variables.xRange = "((?:<|>)=?)?\s*" & xRangePlain;
    variables.exprSpermy = "(?:~>?)" & xRange;

    this.validRange = this._validRange;

    this['expressions'] = { 
      'parse' : "^\s*"&ver&"\s*$"
      ,'parsePackage' : "^\s*([^\/]+)[-@](" &ver&")\s*$"
      ,'parseRange' : "^\s*(" & ver & ")\s+-\s+(" & ver & ")\s*$"
      ,'validComparator' : "^"&exprComparator&"$"
      ,'parseXRange' : "^"& xRange &"$"
      ,'parseSpermy' : "^"& exprSpermy &"$"
    }

    this['regexps'] = { 
      'parse' : new foundry.core.regexp(this.expressions.parse)
      ,'parsePackage' : new foundry.core.regexp(this.expressions.parsePackage)
      ,'parseRange' : new foundry.core.RegExp(this.expressions.parseRange)
      ,'validComparator' : new foundry.core.RegExp(this.expressions.validComparator)
      ,'parseXRange' : new foundry.core.RegExp(this.expressions.parseXRange)
      ,'parseSpermy' : new foundry.core.RegExp(this.expressions.parseSpermy)
    }

    variables.rangeReplace = ">=\1 <=\7"

    // range can be one of:
    // "1.0.3 - 2.0.0" range, inclusive, like ">=1.0.3 <=2.0.0"
    // ">1.0.2" like 1.0.3 - 9999.9999.9999
    // ">=1.0.2" like 1.0.2 - 9999.9999.9999
    // "<2.0.0" like 0.0.0 - 1.9999.9999
    // ">1.0.2 <2.0.0" like 1.0.3 - 1.9999.9999
    variables.starExpression = "(<|>)?=?\s*\*";
    variables.starReplace = "";
    variables.compTrimExpression = "((<|>)?=?)\s*("&ver&"|"&xRangePlain&")";
    variables.compTrimRegExp = new foundry.core.regexp(compTrimExpression);
    variables.compTrimReplace = "\1\3";

    return this;
  }

  public any function _stringify (version) {
    var v = version;
    return arrayToList([v[1]||'', v[2]||'', v[3]||''],".") & (v[4]||'') & (v[5]||'');
  }

  public any function _clean (version) {
    version = this.parse(version);
    if (!version) return version;
    return stringify(version);
  }

  private array function reSplit(regex,value) {
    var local = {};
    local.result = [];

    local.parts = javaCast( "string", arguments.value ).split(
      javaCast( "string", arguments.regex ),
      javaCast( "int", -1 )
    );

    for (local.part in local.parts) {
      arrayAppend(local.result,local.part);
    };

    return local.result;
  }



    public struct function parse(str) {
      console.print("parse: " & str & "// " & this.regexps.parse.match(str).toString());
      return this.regexps.parse.match(str);
    }
    public struct function parsePackage(str) {
      console.print("parsePackage: " & str & "// " & this.regexps.parsePackage.match(str).toString());
      return this.regexps.parsePackage.match(str);
    }
    public struct function validComparator(str) {
      console.print("validComparator: " & str & "// " & this.regexps.validComparator.match(str).toString());
      return this.regexps.validComparator.match(str);
    }
    public struct function parseXRange(str) {
      console.print("parseXRange: " & str & "// " & this.regexps.parseRange.match(str).toString());
      return this.regexps.parseRange.match(str);
    }
    public struct function parseSpermy(str) {
      console.print("parseSpermy: " & str & "// " & this.regexps.parseSpermy.match(str).toString());
      return this.regexps.parseSpermy.match(str);
    }

  public any function valid (version) {
    if (!_.isString(version)) return null;
    parsedVersion = this.regexps.parse.match(version);
    version = trim(version);
    version = reReplace(version,"^[v=]+","");
    console.print("valid version: " & version);
    return !_.isEmpty(parsedVersion) && !_.isEmpty(version);
  }

  public any function _validPackage (version) {
    if (!_.isString(version)) return null;
    var matchedVersion = expressions.parsePackage.match(version);
    return matchedVersion && trim(version);
  }

  public any function toComparators (range) {
    var ret = trim((!_.isEmpty(range)? range : ""));
    console.print("toComparators [ret] default: " & ret);
    ret = rereplacenocase(ret,this.expressions.parseRange,rangeReplace,"ALL");
    
    console.print("toComparators [ret] parseRange: " & ret);
    ret = rereplacenocase(ret,compTrimExpression,compTrimReplace,"ALL");
    console.print("toComparators [ret] compTrim: " & ret);
    
    ret = resplit("\s+",ret);
    console.print("toComparators [ret] split at space: " & ret.toString());
    ret = arrayToList(ret," ");
    console.print("toComparators [ret] back to list: " & ret);
    
    if(ret CONTAINS "||") {
      ret = listToArray(ret,"||");
      console.print("toComparators [ret] split at ||: " & ret.toString());
    }
    
    if(_.isEmpty(ret)) ret = " ";

    ret = _map(ret,function (orchunk) {
            var orchunk = arguments.orchunk;
            orchunk = listToArray(orchunk," ");
            writeDump(label="orchunk listToArray",var=orchunk);
            orchunk = _map(orchunk,this._replaceXRanges);
            writeDump(label="orchunk _replaceXRanges",var=orchunk);
            orchunk = _map(orchunk,this._replaceSpermies);
            writeDump(label="orchunk _replaceSpermies",var=orchunk);
            orchunk = _map(orchunk,this._replaceStars);
            writeDump(label="orchunk _replaceStars",var=orchunk);
            orchunk = arrayToList(orchunk," ");
      return orchunk;
    });

    ret = _map(ret,function (orchunk) {
        orchunk = trim(orchunk);
        orchunk = resplit("\s+",orchunk);
        orchunk = arrayfilter(orchunk,function (c) { return this.regexps.validComparator.test(c); });
        return orchunk;
      });
    ret = arrayfilter(ret,function (c) { return arraylen(c); });
    return ret;
  }

  public any function _replaceStars(stars) {
    stars = trim(stars);
    stars = rereplace(stars,starExpression,starReplace);

    return stars;
  }

 
  
  // "2.x","2.x.x" --> ">=2.0.0- <2.1.0-"
  // "2.3.x" --> ">=2.3.0- <2.4.0-"
  public any function _replaceXRanges(ranges) {
    console.print("should be " & ranges);
    ranges = resplit("\s+",ranges);
    //writeDump(var=ranges,abort=true);
    ranges = _map(ranges,this._replaceXRange);
    ranges = arrayToList(ranges," ");
    return ranges;
  }

  public any function _replaceXRange (version) {
    version = trim(version);
    var v = version;
    var replacer = function (v,gtlt, M, n, p, t) {
      console.print("xrange replacer args: " & serialize(arguments));
      var anyX = isNull(M) ||  _.isEmpty(M) || (M.toLowerCase() EQ "x") || M EQ "*" 
                 || isNull(n) || _.isEmpty(n) || (n.toLowerCase() EQ "x") || n EQ "*"
                 || isNull(p) || _.isEmpty(p) || (p.toLowerCase() EQ "x") || p EQ "*"
      var ret = v;
      console.log("anyX: " & anyX);
      
      if (structKeyExists(arguments,'gtlt') && anyX) {
        // just replace x'es with zeroes
        if(isNull(M) || _.isEmpty(M) || M EQ "*" || (M.toLowerCase() EQ "x")) M = 0;
        if(isNull(n) || _.isEmpty(n) || n EQ "*" || (n.toLowerCase() EQ "x")) n = 0;
        if(isNull(p) || _.isEmpty(p) || p EQ "*" || (p.toLowerCase() EQ "x")) p = 0;
        
        ret = gtlt & M & "." & n & "." & p &"-"

      } else if (isNull(M) || _.isEmpty(M) || M EQ "*" || M.toLowerCase() EQ "x") {
        ret = "*" // allow any
      } else if (isNull(n) || _.isEmpty(n) || n EQ "*" || n.toLowerCase() EQ "x") {
        // append "-" onto the version, otherwise
        // "1.x.x" matches "2.0.0beta", since the tag
        // *lowers* the version value
        ret = ">="&M&".0.0- <"&(+M+1)&".0.0-"
      } else if (isNull(p) || _.isEmpty(p) || p EQ "*" || p.toLowerCase() EQ "x") {
        ret = ">="&M&"."&n&".0- <"&M&"."&(+n+1)&".0-"
      }
      //console.error("parseXRange", [].slice.call(arguments), ret)
      console.print("result of replacer: " & ret.toString());
      return ret;
    };

    console.print("version: " & version);
    var matches = this.regexps.parseXRange.match(version);
    var replacerArgs = {
      'v':!isNull(matches[0])? matches[0] : '',
      'gtlt':!isNull(matches[1])? matches[1] : '',
      'M':!isNull(matches[2])? matches[2] : '',
      'n':!isNull(matches[3])? matches[3] : '',
      'p':!isNull(matches[4])? matches[4] : '',
      't':!isNull(matches[5])? matches[5] : '',
    }
    var result = replacer(argumentCollection=replacerArgs);
    version = rereplace(version,this.expressions.parseXRange,result);
    console.print("now version: " & version);
    return version;
  }

  // ~, ~> --> * (any, kinda silly)
  // ~2, ~2.x, ~2.x.x, ~>2, ~>2.x ~>2.x.x --> >=2.0.0 <3.0.0
  // ~2.0, ~2.0.x, ~>2.0, ~>2.0.x --> >=2.0.0 <2.1.0
  // ~1.2, ~1.2.x, ~>1.2, ~>1.2.x --> >=1.2.0 <1.3.0
  // ~1.2.3, ~>1.2.3 --> >=1.2.3 <1.3.0
  // ~1.2.0, ~>1.2.0 --> >=1.2.0 <1.3.0
  public any function _replaceSpermies (version) {
    version = trim(version);
    var replacer = function (v,gtlt, M, m, p, t) {
      if (structKeyExists(arguments,'gtlt') AND !isNull(gtlt) AND !_.isEmpty(gtlt)) throw (
        "Using '"&gtlt&"' with ~ makes no sense. Don't do it.");

      if (isNull(M) || LCase(M) EQ "x") {
        return "";
      }
      // ~1 == >=1.0.0- <2.0.0-
      if (isNull(n) || LCase(n) EQ "x") {
        return ">="&M&".0.0- <"& (M + 1) & ".0.0-";
      }
      // ~1.2 == >=1.2.0- <1.3.0-
      if (isNull(p) || LCase(p) EQ "x") {
        return ">="&M&"."&n&".0- <"&M&"."& (n + 1) & ".0-";
      }
      // ~1.2.3 == >=1.2.3- <1.3.0-
      t = !isNull(t)? t : "-"
      return ">="&M&"."&n&"."&p&t&" <"&M&"."&(n+1)&".0-";
    };

    console.print("version: " & version);
    var matches = this.regexps.parseSpermy.match(version);
    var replacerArgs = {
        'v':!isNull(matches[0])? matches[0] : '',
        'gtlt':!isNull(matches[1])? matches[1] : '',
        'M':!isNull(matches[2])? matches[2] : '',
        'n':!isNull(matches[3])? matches[3] : '',
        'p':!isNull(matches[4])? matches[4] : '',
        't':!isNull(matches[5])? matches[5] : '',
      }
    var result = replacer(argumentCollection=replacerArgs);
    version = rereplace(version,this.expressions.parseXRange,result);
    console.print("now version: " & version);
    return version;
  }

  public any function _validRange (range) {
    range = _replaceStars(range);
    var c = toComparators(range);
    return (len(c) EQ 0) ? null : arrayToList(_map(c,function (c) { return arrayToList(c," "); }),"||");
  }

  // returns the highest satisfying version in the list, or undefined
  public any function _maxSatisfying (versions, range) {
    versions = arrayfilter(versions,function(v) { return satisfies(v,range); });
    versions = arraysort(_compare,'textnocase');
    versions = new foundry.core.arrayObj(versions);

    return versions.pop();
  }

  public any function satisfies (version, range) {
    console.print("satisfies('" & version & "','" & range & "');");
    version = valid(version);
    if (!version) return false;
    range = toComparators(range);

    var i = 0;
    var l = arrayLen(range);

    for (var i = 1; i <= l ; i ++) {
      var ok = false;
      var ll = arrayLen(range[i]);
      for (var j = 1; j <= ll ; j ++) {
        var r = range[i][j];
        var gtlt = mid(r,1,1) EQ ">" ? gt
                 : mid(r,1,1) EQ "<" ? lt
                 : false;
        if(_.isFunction(gtlt)) gtltDef = true;
        else gtltDef = false;

        console.print("r: " & r);
        var eq = len(r) GT 0? (r.charAt(!!gtltDef) EQ "=") : false;
        var sub = (!!eq) + (!!gtltDef);

        if (!gtltDef) eq = true;
        r = r.substring(sub);
        r = (r EQ "") ? r : valid(r);
        ok = (r EQ "") || (eq && r EQ version) || (gtltDef && gtlt(version, r));
        if (!ok) break;
      }
      if (ok) return true;
    };
    return false;
  };

  // // return v1 > v2 ? 1 : -1
  public any function _compare (v1, v2) {
    var g = gt(v1, v2);
    return ((g EQ null) ? 0 : g) ? 1 : 0;
  }

  public any function _rcompare (v1, v2) {
    return compare(v2, v1);
  }

  public any function lt (v1, v2) { return gt(v2,v1); }
  public any function gte (v1, v2) { return !lt(v1,v2); }
  public any function lte (v1, v2) { return !gt(v1,v2); }
  public any function eq (v1, v2) { return (!gt(v1,v2) AND !lt(v1,v2)); }
  public any function neq (v1, v2) { return (gt(v1, v2) OR lt(v1, v2)); }
  public any function cmp (v1, c, v2) {
    switch (c) {
      case ">": return gt(v1, v2);
      case "<": return lt(v1, v2);
      case ">=": return gte(v1, v2);
      case "<=": return lte(v1, v2);
      case "==": return eq(v1, v2);
      case "!=": return neq(v1, v2);
      case "EQ": return (v1 EQ v2);
      case "NEQ": return (v1 NEQ v2);
      default: throw("Y U NO USE VALID COMPARATOR!? " & c);
    };
  }

  public any function gt () {
    v1 = this.parse(arguments[1]);
    v2 = this.parse(arguments[2]);
    if (structCount(v1) EQ 0 || structCount(v2) EQ 0) return false;

    for (var i = 1; i < 5; i++) {
      var num1 = (structKeyExists(v1,i)? ReReplaceNoCase(v1[i],"[^0-9]","","ALL") : '');
      var num2 = (structKeyExists(v2,i)? ReReplaceNoCase(v2[i],"[^0-9]","","ALL") : '');
      
      if (num1 > num2) {
        return true;
      } else if (num1 NEQ num2) {
        return false;
      }
    }

    // no tag is > than any tag, or use lexicographical order.
    var tag1 = (structKeyExists(v1,5)? v1[5] : '');
    var tag2 = (structKeyExists(v2,5)? v2[5] : '');
    // kludge: null means they were equal.  falsey, and detectable.
    // embarrassingly overclever, though, I know.
  
    var tagResult = (compare(tag1,tag2) EQ 0)? false
      : _.isEmpty(tag1) ? true
      : _.isEmpty(tag2) ? false
      : (compare(tag1,tag2) EQ 1);
    return tagResult;
  }

  public any function _inc (version, release) {
    version = this.parse(version);
    if (!version) return null;

    var parsedIndexLookup = { 
        'major': 1
      , 'minor': 2
      , 'patch': 3
      , 'build': 4 
    }
    var incIndex = parsedIndexLookup[release];
    if (!isDefined(incIndex)) return null;

    var current = _num(version[incIndex])
    version[incIndex] = (current EQ -1) ? 1 : current + 1;

    for (var i = incIndex + 1; i < 5; i ++) {
      if (_num(version[i]) NEQ -1) version[i] = "0";
    }

    if (version[4]) version[4] = "-" + version[4];
    version[5] = "";

    return stringify(version);
  }

   public array function _map(obj,iterator = _.identity, this = {}) {
    var result = [];

    if (isArray(arguments.obj)) {
      var index = 1;
      var resultIndex = 1;
      
      for (element in arguments.obj) {
        if (!arrayIsDefined(arguments.obj, index)) {
          index++;
          continue;
        }
        var local = {};
        local.tmp = iterator(element, index, arguments.obj, arguments.this);
        if (structKeyExists(local, "tmp")) {
          result[resultIndex] = local.tmp;
        }
        index++;
        resultIndex++;
      }
    }

    else if (isObject(arguments.obj) || isStruct(arguments.obj)) {
      var index = 1;
      for (key in arguments.obj) {
        var val = arguments.obj[key];
        var local = {};
        local.tmp = iterator(val, key, arguments.obj, arguments.this);
        if (structKeyExists(local, "tmp")) {
          result[index] = local.tmp;
        }
        index++;
      }
    }
    else {
      // query or something else? convert to array and recurse
      result = _map(_.toArray(arguments.obj), iterator, arguments.this);
    }

    return result;
  }

  public any function regexp_escape(str) {
    return rereplacenocase(arguments.str,"^([.?*+^$[\]\\(){}|-])","\1","all");
  }
}