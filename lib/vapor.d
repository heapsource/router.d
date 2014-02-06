module vapor;

import events;
import std.string : toUpper, toLower;
import std.regex;

package:

class Route(TContext) : EventList!(void, TContext, string[string]) {
    private:

        string _path;
        Regex!char _compiledPath;
        string[] _routeParams;
        EventList!(void, TContext, string[string]).Trigger _eventTrigger;

    public:

        this(string path) {
            _path = path;
            _eventTrigger = this.own;
            _routeParams = extractRouteParams;
            _compiledPath = compilePathRegex;
        }

        @property string path() {
            return _path;
        }

        @property string[] routeParams() {
            return _routeParams;
        }

        @property Regex!char compiledPath() {
            return _compiledPath;
        }

        void execute(string uri, TContext context) {
            auto m = match(uri, _compiledPath);
            string[string] params;

            if(m.captures.length > 0)
            {
                for(int i = 1; i < m.captures.length; i++) {
                    params[_routeParams[i-1]] = m.captures[i];
                }
                _eventTrigger(context, params);
            }
        }

    private:
        string[] extractRouteParams() {
            string[] keys;
            string c;

            foreach(m; match(_path, regex(r"(:\w+)", "gm"))){
                c = m.captures[1];
                keys ~= c[1..c.length];
            }
            return keys;
        }

        Regex!char compilePathRegex() {
            auto replaced = replaceAll(_path, regex(r"(:\w+)","g"), "([^/?#]+)");
            auto compiledRegexp = regex(replaced);
            return compiledRegexp;
        }
}

class VerbHandler(TContext) {
    private:
        string _verb;
        Route!TContext[string] _routes;

    public:

        this(string normalizedVerb) {
            _verb = normalizedVerb;
        }

        @property {
            string verb() {
                return _verb;
            }
        }

        Route!TContext route(string path) {
            Route!TContext route = null;
            if(path in _routes) {
                route = _routes[path];
            }
            if(route is null) {
                route = _routes[path] = new Route!TContext(path);
            }
            return route;
        }

        void execute(string path, TContext context) {
            foreach(r; _routes) {
                r.execute(path, context);
            }
        }
}

private template BootstrapVerb(string methodName) {
    const char[] BootstrapVerb = "EventList!(void, TContext, string[string]) " ~ methodName.toLower ~ "(string path) { return this.map(\"" ~ methodName.toUpper ~ "\", path); }";
}

class Router(TContext) {
    private:
        VerbHandler!TContext[string] _verbs;

        VerbHandler!TContext _getVerb(string verb) {
            string normalizedVerb = verb.toUpper;
            VerbHandler!TContext handler = null;
            if(normalizedVerb in _verbs) {
                handler = _verbs[normalizedVerb];
            }
            if(handler is null) {
                handler = _verbs[normalizedVerb] = new VerbHandler!TContext(normalizedVerb);
            }
            return handler;
        }

    public:

        EventList!(void, TContext, string[string]) map(string verb, string path) {
            auto handler = _getVerb(verb);
            return handler.route(path);
        }

        mixin(BootstrapVerb!"GET");
        mixin(BootstrapVerb!"HEAD");
        mixin(BootstrapVerb!"POST");
        mixin(BootstrapVerb!"PUT");

        void execute(string verb, string path, TContext context) {
            auto handler = _getVerb(verb);
            handler.execute(path, context);
        }
}
