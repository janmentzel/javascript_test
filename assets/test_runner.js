/**
* @requires $.toJSON()
*/
QUnit.rails_test_result = {
  tests : 0
  ,assertions : 0
  ,failures : 0
  ,failedTests : [] /* array of String */
};
QUnit.rails_currenModule = '';
//QUnit.begin = function() {};
//QUnit.log = function(result, message) {};
//QUnit.testStart = function(name, testEnvironment) {};
QUnit.testDone = function(name, failures, total) {
  //console.debug('testDone() name, failures, total: "', name, '" ,', failures, ',', total);
  QUnit.rails_test_result.tests++;
  if(failures > 0) {
    // TODO prepend module name
    QUnit.rails_test_result.failedTests.push(QUnit.rails_currenModule +' '+ name);
  }
};
QUnit.moduleStart = function(name, testEnvironment) {
  //console.debug('moduleStart() name, testEnvironment: ', [name,testEnvironment]);
  QUnit.rails_currenModule = name +':';
};
QUnit.moduleDone = function(name, failures, total) {
  //console.debug('moduleStart() name, failures, total: ', [name, failures, total]);
  QUnit.rails_currenModule = '';
};
QUnit.done = function(failures, total) { 
  //console.debug('done() failures, total: ', failures,',', total)
  // extract resultsURL from querystring
  var urlParams = {};
  (function () {
      var e,
          d = function (s) { return decodeURIComponent(s.replace(/\+/g, " ")); },
          q = window.location.search.substring(1),
          r = /([^&=]+)=?([^&]*)/g;

      while (e = r.exec(q))
         urlParams[d(e[1])] = d(e[2]);
  })();

  QUnit.rails_test_result.failures = failures;
  QUnit.rails_test_result.assertions = total;
  // send test-results back to javascript_test server
  $.post(urlParams.resultsURL, {json: $.toJSON(QUnit.rails_test_result)});
};
