use ExtUtils::MakeMaker;

WriteMakefile
  ( NAME      => 'Log::Report'
  , VERSION   => '0.01'
  , PREREQ_PM => { Test::More => 0.47 }
  , AUTHOR    => 'Mark Overmeer'
  , ABSTRACT  => 'report a problem, pluggable handlers and language support'
  );

sub MY::postamble { <<'__POSTAMBLE' }

# for OODoc's oodist, DIST
RAWDIR          = ../public_html/logreport/raw
DISTDIR         = ../public_html/logreport/source
LICENSE         = artistic

# for OODoc's oodist, POD
FIRST_YEAR      = 2007
EMAIL           = perl@overmeer.net
WEBSITE         = http://perl.overmeer.net/logreport/

# for OODoc's oodist, HTML
HTML_OUTPUT     = ../public_html/logreport/html
HTML_DOCROOT    = /logreport/html
HTML_PACKAGE    = ../public_html/logreport/htmlpkg

# for Log::Report
xgettext: $(TO_INST_PM)
	PERL5LIB=lib bin/xgettext-perl --mode=TRACE \
	    -p lib/Log/Report/messages
__POSTAMBLE
