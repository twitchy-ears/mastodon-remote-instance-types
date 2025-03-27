# mastodon-remote-instance-types
A very quick hack for dumping out some information for helping you guess the kind of software running on instances connected to yours

As per the --help

remote-instance-types.pl [-h|-d] 

 -h --help
 -d --debug      Display more information prefixed with DD: 

 --count         Add a counter for [x/y] to track progress

 --http-timeout  Set timeout for API requests, 
                 default 2

 --dump-list     Just dump the list, don't fetch anything.

 --mode <m>      Create target domain list from mode, options are:
                 followers  (domains with users followed by users here)
                 all        (read every known instance with >1 user seen)
                 
                 Default: 'followers'


Attempts to connect to the mastodon_production DB as the mastodon user without
a password, authenticating as the logged in user.  Dumps instances depending on
the --mode argument then attempts to retrieve the mastodon v2 API instance
information from it. Prints one of these options:

OK: 'url' -> 'source_url'
FAIL: 'url' malformed JSON
FAIL: 'url' had no source_url
FAIL: 'url' had no response
FAIL: 'url' status 'code'

The source_url should be a repo of the remote instances source, which enables
you to best guess its instance type.
