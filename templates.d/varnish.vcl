/* This is the default varnish cache server configuration.
   Note that cache.conf is generated from cache.conf.template.
*/

vcl 4.0;

/* Configure zope client as back end */
backend balancer {
    .host = "${settings:haproxy-host}";
    .port = "${settings:haproxy-port}";
    .connect_timeout = 0.4s;
    .first_byte_timeout = 300s;
    .between_bytes_timeout = 60s;

}

/* Only allow PURGE from localhost */
acl purge_allowed {
    "localhost";
    "127.0.0.1";
    /* Just in case the purge host is not in the same machine */
    /* Do not forget to add its IP */
}

sub vcl_recv {

  # Sanitize compression handling
  if (req.http.Accept-Encoding) {
      if (req.url ~ "\.(jpg|png|gif|gz|tgz|bz2|tbz|mp3|ogg)$") {
          # No point in compressing these
          unset req.http.Accept-Encoding;
      } elsif (req.http.Accept-Encoding ~ "gzip") {
          set req.http.Accept-Encoding = "gzip";
      } elsif (req.http.Accept-Encoding ~ "deflate" && req.http.user-agent !~ "MSIE") {
          set req.http.Accept-Encoding = "deflate";
      } else {
          # unknown algorithm
          unset req.http.Accept-Encoding;
      }
  }

  # Handle special requests
  if (req.method != "GET" && req.method != "HEAD") {
     # POST - Logins and edits
     if (req.method == "POST") {
         return(pass);
     }
     /* Purge allowed only from some hosts */
     if (req.method == "PURGE") {
         if (client.ip ~ purge_allowed) {
            return(purge);
         } else {
            return(synth(403, "Purge not allowed from this host. Access denied."));
         }
     }
  }

  /* Do not cache AJAX requests */
  if (req.http.X-Requested-With == "XMLHttpRequest") {
      return(pass);
  }

  # Sanitize cookies so they do not needlessly destroy cacheability for anonymous pages
  if (req.http.Cookie) {
      set req.http.Cookie = ";" + req.http.Cookie;
      set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
      set req.http.Cookie = regsuball(req.http.Cookie, ";(I18N_LANGUAGE|statusmessages|__ac|_ZopeId|__cp|beaker\.session|authomatic|serverid)=", "; \1=");
      set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
      set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");

      if (req.http.Cookie == "") {
          unset req.http.Cookie;
      }
  }

  # Annotate request with X-Anonymous header if anonymous
  if (!(req.http.Cookie && req.http.Cookie ~ "__ac(|_(name|password|persistent))=")) {
      set req.http.X-Anonymous = "True";
  }

  # Keep auth/anon variants apart if "Vary: X-Anonymous" is in the response
  if (!(req.http.Authorization || req.http.Cookie ~ "(^|.*; )__ac=")) {
      set req.http.X-Anonymous = "True";
  }

  return(hash);

}

sub vcl_pipe {
    /* This is not necessary if you do not do any request rewriting. */
    set req.http.connection = "close";
}

sub vcl_hit {
    if (!obj.ttl > 0s) {
        return(pass);
    }
}

sub vcl_miss {
    if (req.method == "PURGE") {
        return (synth(404, "Not in cache miss"));
    }

}

sub vcl_backend_response {

    # Don't allow static files to set cookies.
    # (?i) denotes case insensitive in PCRE (perl compatible regular expressions).
    # make sure you edit both and keep them equal.
    if (bereq.url ~ "(?i)\.(pdf|asc|dat|txt|doc|xls|ppt|tgz|png|gif|jpeg|jpg|ico|swf|css|js)(\?.*)?$") {
      unset beresp.http.set-cookie;
    }

    /* commented */
       /*if (!obj.ttl > 0s) {
        set beresp.http.X-Varnish-Action = "FETCH (pass - not cacheable)";
        set beresp.uncacheable = true;
        set beresp.ttl = 120s;
        return(deliver);
       }*/

    if (beresp.http.Set-Cookie) {
        set beresp.http.X-Varnish-Action = "FETCH (pass - response sets cookie)";
        set beresp.uncacheable = true;
        set beresp.ttl = 120s;
        return(deliver);
    }
    if (beresp.http.Cache-Control ~ "(private|no-cache|no-store)") {
        set beresp.http.X-Varnish-Action = "FETCH (pass - cache control disallows)";
        set beresp.uncacheable = true;
        set beresp.ttl = 120s;
        return(deliver);
    }
    if (beresp.http.Authorization && !beresp.http.Cache-Control ~ "public") {
        set beresp.http.X-Varnish-Action = "FETCH (pass - authorized and no public cache control)";
        set beresp.uncacheable = true;
        set beresp.ttl = 120s;
        return(deliver);
    }

    if (beresp.http.X-Anonymous && !beresp.http.Cache-Control) {
        set beresp.http.X-Varnish-Action = "FETCH (override - backend not setting cache control)";
        set beresp.ttl = 600s;
        return (deliver);
    }

    if (!beresp.http.Cache-Control) {
        set beresp.http.X-Varnish-Action = "FETCH (override - backend not setting cache control)";
        set beresp.uncacheable = true;
        set beresp.ttl = 120s;
        return (deliver);
    }

    set beresp.http.X-Varnish-Action = "FETCH (insert)";

    set beresp.grace = 120s;

    return (deliver);
}

sub vcl_hash {
    hash_data(req.url);
    hash_data(req.http.host);

    if (req.http.Accept-Encoding ~ "gzip") {
        hash_data("gzip");
    }
    else if (req.http.Accept-Encoding ~ "deflate") {
        hash_data("deflate");
    }

      /* With PAM this is no longer needed
      if (req.http.cookie ~ "I18N_LANGUAGE") {
          hash_data(regsub( req.http.Cookie, "^.*?I18N_LANGUAGE=([^;]*?);*.*$", "\1" ) );
      }
      */

}

sub vcl_deliver {
        if (obj.hits > 0) {
                set resp.http.X-Cache = "HIT";
        } else {
                set resp.http.X-Cache = "MISS";
        }
}
