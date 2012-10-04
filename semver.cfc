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
    
    variables.exprComparator = "^((<|>)?=?)\s*("&ver&")$|^$"
    
    variables.xRangePlain = "[v=]*([0-9]+|x|X|\*)"
                          & "(?:\.([0-9]+|x|X|\*)"
                          & "(?:\.([0-9]+|x|X|\*)"
                          & "([a-zA-Z-][a-zA-Z0-9-.:]*)?)?)?";
    
    variables.xRange = "((?:<|>)=?)?\s*" & xRangePlain;
    
    variables.exprSpermy = "(?:~>?)" & xRange;

    this.validRange = this._validRange;

    this['expressions'] = { 
      'parse' : new foundry.core.regexp("^\s*"&ver&"\s*$")
      ,'parsePackage' : new foundry.core.regexp("^\s*([^\/]+)[-@](" &ver&")\s*$")
      ,'parseRange' : new foundry.core.regexp("^\s*(" & ver & ")\s+-\s+(" & ver & ")\s*$")
      ,'validComparator' : new foundry.core.regexp("^"&exprComparator&"$")
      ,'parseXRange' : new foundry.core.regexp("^"& xRange &"$")
      ,'parseSpermy' : new foundry.core.regexp("^"& exprSpermy &"$")
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
    variables.compTrimExpression = new foundry.core.regexp("((<|>)?=?)\s*("&ver&"|"&xRangePlain&")");
    variables.compTrimReplace = "\1\3";

    return this;
  }

  public any function _stringify (version) {
    var v = version;
    return arrayToList([(!isNull(v[1])? v[1] : ''), (!isNull(v[2])? v[2] : ''), (!isNull(v[3])? v[3] : '')],".") & (!isNull(v[4])? v[4] : '') & ((!isNull(v[5])? v[5] : ''));
  }

  public any function _clean (version) {
    version = this.parse(version);
    if (structCount(version) EQ 0) return version;
    return _stringify(version);
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
      return this.expressions.parse.match(str);
    }
    public struct function parsePackage(str) {
      return this.expressions.parsePackage.match(str);
    }
    public struct function validComparator(str) {
      return this.expressions.validComparator.match(str);
    }
    public struct function parseXRange(str) {
      return this.expressions.parseRange.match(str);
    }
    public struct function parseSpermy(str) {
      return this.expressions.parseSpermy.match(str);
    }

  public any function valid (version) {
    if (!_.isString(version)) return null;
    parsedVersion = this.expressions.parse.match(version);
    version = trim(version);
    version = reReplace(version,"^[v=]+","");
    if(structCount(parsedVersion) GT 0) {
      return version;
    } else {
      return false;
    }
  }

  public any function _validPackage (version) {
    if (!_.isString(version)) return null;
    var matchedVersion = expressions.parsePackage.match(version);
    return matchedVersion && trim(version);
  }

  public any function toComparators (range) {
    var ret = trim((!_.isEmpty(range)? range : ""));
    ret = this.expressions.parseRange.replace(ret,rangeReplace);
    ret = compTrimExpression.replace(ret,compTrimReplace);
    ret = resplit("\s+",ret);
    ret = arrayToList(ret," ");
    
    if(ret CONTAINS "||") {
      ret = listToArray(" " & ret & " ","||");
    }
    
    if(_.isEmpty(ret)) ret = [""];
    ret = _map(ret,function (orchunk) {
            var orchunk = arguments.orchunk;
            orchunk = listToArray(orchunk," ");
            orchunk = _map(orchunk,this._replaceXRanges);
            orchunk = _map(orchunk,this._replaceSpermies);
            orchunk = _map(orchunk,this._replaceStars);
            orchunk = arrayToList(orchunk," ");
      return orchunk;
    });
    ret = _map(ret,function (orchunk) {
       orchunk = trim(orchunk);
        orchunk = resplit("\s+",orchunk);
       orchunk = arrayfilter(orchunk,function (c) { 
                      var isValid = this.expressions.validComparator.test(c);
                     
                      return isValid; });
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
    ranges = resplit("\s+",ranges);
    
    ranges = _map(ranges,this._replaceXRange);

    ranges = arrayToList(ranges," ");
    return ranges;
  }

  public any function _replaceXRange (version) {
    version = trim(version);
    return this.expressions.parseXRange.replace(version,function (v,gtlt, M, n, p, t) {
          //console.print("#chr(10)#===== XRANGE REPLACER START")
          //console.print(serialize(arguments));

          var anyX = _.isEmpty(M) || M.toLowerCase() EQ "x" || M EQ "*"
                     || _.isEmpty(n) || n.toLowerCase() EQ "x" || n EQ "*"
                     || _.isEmpty(p) || p.toLowerCase() EQ "x" || p EQ "*";
          var ret = v;
          ////console.print()
          ////console.print("gtlt: " & gtlt.toString());
          if (!_.isEmpty(gtlt) && anyX) {
            // just replace x'es with zeroes
            if(_.isEmpty(M) || M EQ "*" || M.toLowerCase() EQ "x") M = 0;
            if(_.isEmpty(n) || n EQ "*" || n.toLowerCase() EQ "x") n = 0;
            if(_.isEmpty(p) || p EQ "*" || p.toLowerCase() EQ "x") p = 0;
            
            ret = gtlt & M &"."&n&"."&p&"-";
            //console.print("firstif ret: " & serialize(ret));
            //console.print("===== REPLACER END#chr(10)#");
          } else if (_.isEmpty(M) || M EQ "*" || M.toLowerCase() EQ "x") {
            ret = "*";
            //console.print("secif ret: " & serialize(ret));
            //console.print("===== REPLACER END#chr(10)#");
          } else if (_.isEmpty(n) || n EQ "*" || n.toLowerCase() EQ "x") {
            // append "-" onto the version, otherwise
            // "1.x.x" natches "2.0.0beta", since the tag
            // *lowers* the version value
            ret = ">="&M&".0.0- <"&(+M+1)&".0.0-";
            //console.print("thirdif ret: " & serialize(ret));
            //console.print("===== REPLACER END#chr(10)#");
          } else if (_.isEmpty(p) || p EQ "*" || p.toLowerCase() EQ "x") {
            ret = ">="&M&"."&n&".0- <"&M&"."&(+n+1)&".0-";
            //console.print("fourthif ret: " & serialize(ret));
            //console.print("===== REPLACER END#chr(10)#");
          } else {
            //console.print("noif ret: " & serialize(ret));
            //console.print("#chr(10)#===== XRANGE REPLACER END");
          }
        //console.print("#chr(10)#===== XRANGE END");
        //console.print(serialize(ret));
        return ret;
    });

        
  };

  // ~, ~> --> * (any, kinda silly)
  // ~2, ~2.x, ~2.x.x, ~>2, ~>2.x ~>2.x.x --> >=2.0.0 <3.0.0
  // ~2.0, ~2.0.x, ~>2.0, ~>2.0.x --> >=2.0.0 <2.1.0
  // ~1.2, ~1.2.x, ~>1.2, ~>1.2.x --> >=1.2.0 <1.3.0
  // ~1.2.3, ~>1.2.3 --> >=1.2.3 <1.3.0
  // ~1.2.0, ~>1.2.0 --> >=1.2.0 <1.3.0
  public any function _replaceSpermies (version) {
    version = trim(version);
    //console.print("#chr(10)#= SPERMS START");
    //console.print("args: " & serialize(arguments));

    ////console.print("version: " & version);
    return this.expressions.parseSpermy.replace(version,function (v,gtlt, M, n, p, t) {
            //console.print("#chr(10)#===== SPERM REPLACER START")
            //console.print(serialize(arguments));
            
            gtlrExists = (!isNull(gtlt) AND !_.isEmpty(gtlt));
            
            if (gtlrExists) throw ("Using '" & gtlt & "' with ~ makes no sense. Don't do it.");

            if (isNull(M) || _.isEmpty(M) || LCase(M) EQ "x") {
              //console.print("M: " & "");
              //console.print("===== REPLACER END#chr(10)#");
              return "";
            }

            // ~1 == >=1.0.0- <2.0.0-
            if (isNull(n) || _.isEmpty(n) || LCase(n) EQ "x") {
              //console.print("return: " & ">="&M&".0.0- <" & (+M + 1) & ".0.0-");
              //console.print("===== REPLACER END#chr(10)#");
              return ">="&M&".0.0- <" & (+M + 1) & ".0.0-";
            }

            // ~1.2 == >=1.2.0- <1.3.0-
            if (isNull(p) || _.isEmpty(p) || LCase(p) EQ "x") {
              //console.print("return: " & ">="&M&"."&n&".0- <"&M&"." & (+n + 1) & ".0-");
              //console.print("===== REPLACER END#chr(10)#");
              return ">="&M&"."&n&".0- <"&M&"." & (+n + 1) & ".0-";
            }

            // ~1.2.3 == >=1.2.3- <1.3.0-
            t = !isNull(t) AND !_.isEmpty(t)? t : "-";
            //console.print("return: " & ">="&M&"."&n&"."&p&t&" <"&M&"."&(+n+1)&".0-");
            //console.print("===== REPLACER END#chr(10)#");
            return ">="&M&"."&n&"."&p&t&" <"&M&"."&(+n+1)&".0-";
    });
  }

  public any function _validRange (range) {
    //console.print("|||||||||||||||||||||||||||||");
    range = _replaceStars(range);
    //console.print("validRange BEFORE: " & serialize(range));
    var c = toComparators(range);
    //console.print("validRange AFTER: " & serialize(c));

    //console.print("|||||||||||||||||||||||||||||");
    return (arrayLen(c) EQ 0) ? '' : arrayToList(_map(c,function (c) { return arrayToList(c," "); }),"||");
  }

  // returns the highest satisfying version in the list, or undefined
  public any function _maxSatisfying (versions, range) {
    versions = arrayfilter(versions,function(v) { return satisfies(v,range); });
    versions = arraysort(_compare,'textnocase');
    versions = new foundry.core.arrayObj(versions);

    return versions.pop();
  }

  public any function satisfies (version, range) {
    //console.print("satisfies('" & version & "','" & range & "');");
    version = valid(version);
    if (isBoolean(version)) return false;

    //console.print("version: " & version);
    //console.print("range: " & range.toString());

    //console.print("range before: " & serialize(range));
    range = toComparators(range);

    //console.print("range after: " & serialize(range));
    var i = 0;
    var l = arrayLen(range);

    for (var i = 1; i <= l ; i ++) {
      var ok = false;
      var ll = arrayLen(range[i]);
      for (var j = 1; j <= ll ; j ++) {

      //console.print("------------");
        var r = range[i][j];
        var gtlt = !_.isEmpty(r) AND r.charAt(0) EQ ">" ? gt
                 : !_.isEmpty(r) AND r.charAt(0) EQ "<" ? lt
                 : false;
        //console.print("r: " & serialize(r));
        //console.print("gtlt: " & serialize(gtlt.toString()));
        
        if(_.isFunction(gtlt)) gtltDef = true;
        else gtltDef = false;

        var eq = len(r) GT 0? (r.charAt(!!gtltDef) EQ javaCast('string',"=")) : false;
        ////console.print("charAt: " & serialize(javaCast('string',r.charAt(!!gtltDef))));
        //console.print("eq: " & serialize(eq));
        var sub = (!!eq) + (!!gtltDef);
        //console.print("sub: " & serialize(sub));
        //console.print("r: " & serialize(r));

        if (!gtltDef) eq = true;
        r = r.substring(sub);
        //console.print("r: " & serialize(r));
        r = (trim(r) EQ "") ? r : valid(r);
        //console.print("r: " & serialize(r));
        //console.print("#version# #gtlt.toString()# #r#");
        ok = (r EQ "") || (eq && r EQ version) || (_.isFunction(gtlt) && gtlt(version,r));
        //console.print("ok: " & serialize(ok));
        if (!ok) break;
      }
      if (ok) return true;
    };
    return false;
  };



  // return v1 > v2 ? 1 : -1
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
  
  function num (v) {
   return isNull(v) ? -1 : ReReplaceNoCase(v,"[^0-9]","","ALL");
  }

  public any function _inc (version, release) {
    //console.print('args: ' & serialize(arguments));

    version = this.expressions.parse.match(version);

    if (structCount(version) LTE 0) return '';

    var parsedIndexLookup =
      { 'major': 1
      , 'minor': 2
      , 'patch': 3
      , 'build': 4 }
    
    if (!structKeyExists(parsedIndexLookup,release)) return '';
    var incIndex = parsedIndexLookup[release]


    var current = num((!structKeyExists(version,incIndex)? 0 : version[incIndex]));
    version[incIndex] = current === -1 ? 1 : current + 1;

    for (var i = incIndex + 1; i < 5; i ++) {
      if (structKeyExists(version,i) AND num(version[i]) !== -1) version[i] = "0";
    }

    if (structKeyExists(version,'4') AND version[4]) version[4] = "-" & version[4];
    version[5] = "";

    return _stringify(version);
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

  public struct function arrayCollection(array arr) {
    var local = {};
    local.keys = createObject( "java", "java.util.LinkedHashMap" ).init();

    for(var i=1; i <= arrayLen(arguments.arr); i++) {
      if (arrayIsDefined( arguments.arr, i)) {
        local.keys.put(javaCast( "string", i),arguments.arr[i]);
      };
    };
   
    return local.keys;
  }

  private void function returnNull() {}
}