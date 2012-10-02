component name="semver" extends="foundry.core" {
  public any function init() {
    // See http://semver.org/
    // This implementation is a *hair* less strict in that it allows
    // v1.2.3 things, and also tags that don't begin with a char.
    variables._ = require("util").init();
    variables.console = new foundry.core.console();
    variables.ver = "\\s*[v=]*\\s*([0-9]+)"  // major
                & "\\.([0-9]+)"           // minor
                & "\\.([0-9]+)"           // patch
                & "(-[0-9]+-?)?"          // build
                & "([a-zA-Z-][a-zA-Z0-9-\.:]*)?"; // tag
    variables.exprComparator = "^((<|>)?=?)\s*("&ver&")$|^$";
    variables.xRangePlain = "[v=]*([0-9]+|x|X|\\*)"
                    & "(?:\\.([0-9]+|x|X|\\*)"
                    & "(?:\\.([0-9]+|x|X|\\*)"
                    & "([a-zA-Z-][a-zA-Z0-9-\.:]*)?)?)?";
    variables.xRange = "((?:<|>)=?)?\\s*" & xRangePlain;
    variables.exprSpermy = "(?:~>?)" & xRange;

    this.validRange = this._validRange;

    this['expressions'] = { 
      'parse' : new foundry.core.regexp("^\\s*"&ver&"\\s*$")
      ,'parsePackage' : new foundry.core.regexp("^\\s*([^\/]+)[-@](" &ver&")\\s*$")
      ,'parseRange' : new foundry.core.RegExp("^\\s*(" & ver & ")\\s+-\\s+(" & ver & ")\\s*$")
      ,'validComparator' : new foundry.core.RegExp("^"&exprComparator&"$")
      ,'parseXRange' : new foundry.core.RegExp("^"& xRange &"$")
      ,'parseSpermy' : new foundry.core.RegExp("^"& exprSpermy &"$")
    }

    structEach(this.expressions,function(i) {
      this['#i#'] = function(str) {
        return this.expressions[i].match("" & (str || ""));
      }
    });

    variables.rangeReplace = ">=$1 <=$7"
    // this.clean = clean
    // this.compare = compare
    // this.rcompare = rcompare
    // this.satisfies = satisfies
    // this.gt = gt
    // this.gte = gte
    // this.lt = lt
    // this.lte = lte
    // this.eq = eq
    // this.neq = neq
    // this.cmp = cmp
    // this.inc = inc

    // this.valid = valid
    // this.validPackage = validPackage
    // this.validRange = validRange
    // this.maxSatisfying = maxSatisfying

    // this.replaceStars = replaceStars
    // this.toComparators = toComparators

    // range can be one of:
    // "1.0.3 - 2.0.0" range, inclusive, like ">=1.0.3 <=2.0.0"
    // ">1.0.2" like 1.0.3 - 9999.9999.9999
    // ">=1.0.2" like 1.0.2 - 9999.9999.9999
    // "<2.0.0" like 0.0.0 - 1.9999.9999
    // ">1.0.2 <2.0.0" like 1.0.3 - 1.9999.9999
    variables.starExpression = "(<|>)?=?\s*\*";
    variables.starReplace = "";
    variables.compTrimExpression = new foundry.core.regexp("((<|>)?=?)\\s*("&ver&"|"&xRangePlain&")", "g");
    variables.compTrimReplace = "$1$3";

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
      arrayAppend(local.result,local.part );
    };

    return local.result;
  }

  public any function _valid (version) {
    if (!arrayisString(version)) return null;
    parsedVersion = this.parse(version);
    version = trim(version);
    version = reReplace(version,"^[v=]+","");
    return parsedVersion && version;
  }

  public any function _validPackage (version) {
    if (!arrayisString(version)) return null;
    var matchedVersion = expressions.parsePackage.match(version);
    return matchedVersion && trim(version);
  }

  public any function _toComparators (range) {
    var ret = trim((!_.isEmpty(range)? range : ""));
    ret = rereplace(ret,this.expressions.parseRange.getPattern(),rangeReplace);
    ret = rereplace(ret,compTrimExpression.getPattern(),compTrimReplace);
    ret = resplit("\s+",ret);
    ret = arrayToList(ret," ");
    ret = resplit("||",ret);
    
    ret = _map(ret,function (orchunk) {
            var response = arguments.orchunk;
            console.log("in");
            response = resplit(response," ");
            response = _map(response,this._replaceXRanges);
            response = _map(response,this._replaceSpermies);
            response = _map(response,this._replaceStars);
            response = arrayToList(response," ");
      return response;
    });
    ret = _map(ret,function (orchunk) {
        orchunk = trim(orchunk);
        orchunk = resplit(orchunk,"\s+");
        orchunk = arrayfilter(orchunk,function (c) { return c.match(this.expressions.validComparator); });
        return orchunk;
      })
    ret = arrayfilter(ret,function (c) { return c.length; });
    return ret;
  }

  public any function _replaceStars (stars) {
    stars = trim(stars);
    stars = replace(starExpression,stars,starReplace);

    return stars;
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
      result = _map(toArray(arguments.obj), iterator, arguments.this);
    }

    return result;
  }
  // "2.x","2.x.x" --> ">=2.0.0- <2.1.0-"
  // "2.3.x" --> ">=2.3.0- <2.4.0-"
  public any function _replaceXRanges(ranges) {
    ranges = resplit("\s+",ranges);
    writeDump(var=ranges,abort=true);
    ranges = _map(ranges,this._replaceXRange);
    ranges = arrayToList(ranges," ");
    return ranges;
  }

  public any function _replaceXRange (version,gtlt,M1,m2,p,t) {
    version = trim(version);
    var v = version;
    writeDump(var=arguments,abort=true);
    var anyX = (!isDefined("M1") || LCase(M1) EQ "x" || M1 EQ "*"
                 || !isDefined("m2") || LCase(m2) EQ "x" || m2 EQ "*"
                 || !isDefined("p") || LCase(p) EQ "x" || p EQ "*");
    var ret = v;

      if (isDefined("gtlt") && isDefined("anyX")) {
        // just replace x-es with zeroes
        (!isDefined("M1") || M1 EQ "*" || LCase(M1) EQ "x") && (M1 = 0);
        (!isDefined("m2") || m2 EQ "*" || LCase(m2) EQ "x") && (m2 = 0);
        (!isDefined("p") || p EQ "*" || LCase(p) EQ "x") && (p = 0);
        ret = gtlt & M1&"."&m2&"."&p&"-";
      } else if (!isDefined("M1") || M1 EQ "*" || LCase(M1) EQ "x") {
        ret = "*"; // allow any
      } else if (!isDefined("m2") || m2 EQ "*" || LCase(m2) EQ "x") {
        // append "-" onto the version, otherwise
        // "1.x.x" matches "2.0.0beta", since the tag
        // *lowers* the version value
        ret = ">=" & M1 & ".0.0- <" & (M1 + 1) & ".0.0-";
      } else if (!isDefined("p") || p EQ "*" || LCase(p) EQ "x") {
        ret = ">="&M1&"."&m2&".0- <"&M1&"." & (m2+1) & ".0-";
      }
      //console.error("parseXRange", [].slice.call(arguments), ret)

    version = rereplace(version,this.expressions.parseXRange.getPattern(),ret);
      
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
    version = replace(version,this.expressions.parseSpermy,
                                  function (v, gtlt, M, m, p, t) {
      if (gtlt) throw (
        "Using '"&gtlt&"' with ~ makes no sense. Don't do it.");

      if (!M || LCase(M) EQ "x") {
        return "";
      }
      // ~1 == >=1.0.0- <2.0.0-
      if (!m || LCase(m) EQ "x") {
        return ">="&M&".0.0- <"& (M + 1) & ".0.0-";
      }
      // ~1.2 == >=1.2.0- <1.3.0-
      if (!isDefined("p") || LCase(p) EQ "x") {
        return ">="&M&"."&m&".0- <"&M&"."& (m + 1) & ".0-";
      }
      // ~1.2.3 == >=1.2.3- <1.3.0-
      t = t || "-"
      return ">="&M&"."&m&"."&p&t&" <"&M&"."&(m+1)&".0-";
      });
      
      return version;
  }

  public any function _validRange (range) {
    range = _replaceStars(range);
    var c = _toComparators(range);
    return (len(c) EQ 0) ? null : arrayToList(_map(c,function (c) { return arrayToList(c," "); }),"||");
  }

  // returns the highest satisfying version in the list, or undefined
  public any function _maxSatisfying (versions, range) {
    versions = arrayfilter(versions,function(v) { return satisfies(v,range); });
    versions = arraysort(compare,'textnocase');
    versions = new foundry.core.arrayObj(versions);

    return versions.pop();
  }

  public any function _satisfies (version, range) {
    version = valid(version);
    if (!version) return false;
    range = toComparators(range);
    
    var i = 0;
    var l = arrayLen(range);

    while (i < l) {
      i++;
      var ok = false;
      var j = 0;
      var ll = arrayLen(range[i]);

      while (j < ll) {
        j++;
        var r = range[i][j];
        var gtlt = left(r,1) EQ ">" ? gt : left(r,1) EQ "<" ? lt : false;
        var eq = r.charAt(!!gtlt) EQ "=";
        var sub = (!!eq) + (!!gtlt);

        if (!gtlt) eq = true;

        r = r.substr(sub);
        r = (r EQ "") ? r : valid(r);
        ok = (r EQ "") || (eq && r EQ version) || (gtlt && gtlt(version, r));
        if (!ok) break;
      }
      if (ok) return true;
    }
    return false;
  }

  // // return v1 > v2 ? 1 : -1
  public any function _compare (v1, v2) {
    var g = gt(v1, v2);
    return ((g EQ null) ? 0 : g) ? 1 : 0;
  }

  public any function _rcompare (v1, v2) {
    return compare(v2, v1);
  }

  public any function _lt (v1, v2) { return gt(v2, v1); }
  public any function _gte (v1, v2) { return !lt(v1, v2); }
  public any function _lte (v1, v2) { return !gt(v1, v2); }
  public any function _eq (v1, v2) { return (gt(v1, v2) EQ null); }
  public any function _neq (v1, v2) { return (gt(v1, v2) NEQ null); }
  public any function _cmp (v1, c, v2) {
    switch (c) {
      case ">": return gt(v1, v2);
      case "<": return lt(v1, v2);
      case ">=": return gte(v1, v2);
      case "<=": return lte(v1, v2);
      case "==": return eq(v1, v2);
      case "!=": return neq(v1, v2);
      case "EQ": return (v1 EQ v2);
      case "NEQ": return (v1 NEQ v2);
      default: throw ("Y U NO USE VALID COMPARATOR!? "&c);
    };
  }

  // // return v1 > v2
  public any function _num (v) {
    return (isDefined(v) ? 0 : reReplace(v||"0","[^0-9]+","", 10));
  }

  public any function _gt (v1, v2) {
    v1 = this.parse(v1);
    v2 = this.parse(v2);
    if (!v1 || !v2) return false;

    for (var i = 1; i < 5; i ++) {
      v1[i] = num(v1[i]);
      v2[i] = num(v2[i]);
      if (v1[i] > v2[i]) return true;
      else if (v1[i] NEQ v2[i]) return false;
    }
    // no tag is > than any tag, or use lexicographical order.
    var tag1 = v1[5] || "";
    var tag2 = v2[5] || "";

    // kludge: null means they were equal.  falsey, and detectable.
    // embarrassingly overclever, though, I know.
    return (((tag1 EQ tag2) ? null
                   : !tag1) ? true
               : !tag2) ? false
           : tag1 > tag2;
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

    var current = num(version[incIndex])
    version[incIndex] = (current EQ -1) ? 1 : current + 1;

    for (var i = incIndex + 1; i < 5; i ++) {
      if (num(version[i]) NEQ -1) version[i] = "0";
    }

    if (version[4]) version[4] = "-" + version[4];
    version[5] = "";

    return stringify(version);
  }
}