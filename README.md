# Bastion Build Pack

The Bastion Build Pack allows a Cedar application to make transparent
use of SSH bastions to access network endpoints, such as databases.

## Example

    $ heroku config:set BUILDPACK_URL=https://github.com/heroku/heroku-buildpack-multi.git -a sushi

    $ echo 'https://github.com/heroku/heroku-buildpack-ruby.git
    https://github.com/heroku/heroku-buildpack-ruby.git' > .buildpacks

    $ git add .buildpacks
	$ git commit -m'Enable Bastion build pack'
	$ git push heroku master

## Theory of Operation

This build pack emits a `.profile.d` script that runs a program that
searches for configuration variables that form a cohort like:

    <FOO>_<*>
	[<FOO>_<*>]
    <FOO>_BASTIONS
    <FOO>_BASTION_KEY

Upon finding `BASTIONS` and `BASTION_KEY`, every environment variable
with a name matching `<FOO>_*` is parsed as a URL.  Ones that parse
successfully are recorded for further processing.

Then, one `ssh` process is created for every successfully parsed URL
using `-L` to create a tunnel.  This sub-process is supervised and
restarted.  The port on `localhost` performing the forwarding is
chosen randomly and dynamically.

Finally, these dynamically chosen ports are used to rewrite the
environment of the application, which can connect without further
modification.

An example:

    $ heroku config -a sushi
    DATABASE_BASTIONS:             @ref:smiling-boldly-9501:bastions
    DATABASE_BASTION_KEY:          @ref:smiling-boldly-9501:bastion-key
    DATABASE_BASTION_REKEYS_AFTER: @ref:smiling-boldly-9501:bastion-rekeys-after
    DATABASE_URL:                  @ref:smiling-boldly-9501:url

	$ heroku run printenv DATABASE_URL -a sushi
    postgres://username:password@localhost:54278/database-name

## Environment Cleaning

This implementation leverages `ssh-agent` processes to hold credential
information for the target network locations.

This allows the implementation to clear every process in the container
of sensitive Bastion information.

This hardens against two attack vectors:

* File traversal attacks that allow listing of `/proc/<pid>/environ`
* Accidentally allowed diagnostic output echoing environment variables.

For example:

    $ heroku run bash -a sushi
    $ strings /proc/*/environ | fgrep BASTION
    strings: /proc/10/environ: Permission denied
    strings: /proc/1/environ: Permission denied
    DATABASE_BASTION_REKEYS_AFTER=2015-08-01T18:50:00Z
    DATABASE_BASTION_REKEYS_AFTER=2015-08-01T18:50:00Z
    DATABASE_BASTION_REKEYS_AFTER=2015-08-01T18:50:00Z
    DATABASE_BASTION_REKEYS_AFTER=2015-08-01T18:50:00Z
    DATABASE_BASTION_REKEYS_AFTER=2015-08-01T18:50:00Z
    DATABASE_BASTION_REKEYS_AFTER=2015-08-01T18:50:00Z

Notably, neither `*_BASTIONS` nor `*_BASTION_KEY` information is seen
above.

The caveat is that it *is* possible for a process that starts early in
the Dyno boot process to possess the original, sensitive environment.
That happens if some other background process manages to start before
`heroku-buildpack-bastion` has the opportunity to clean the
environment.  This is thought to only be possible if Heroku Runtime
processes are not sanitized or there is a profile script that starts a
background process before the the cleaning can take place.
