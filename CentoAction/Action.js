// Safari: передаёт расширению выделенный на странице текст.
var Action = function() {};

Action.prototype = {
    run: function(parameters) {
        parameters.completionFunction({ "selection": window.getSelection().toString() });
    },
    finalize: function(parameters) {}
};

var ExtensionPreprocessingJS = new Action;
