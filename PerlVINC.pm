package Apache::PerlVINC;

use strict;
use Apache::ModuleConfig ();
use Apache::Constants qw(DECLINE_CMD OK DECLINED);
use DynaLoader ();

$Apache::PerlVINC::VERSION = '0.02';


if($ENV{MOD_PERL}) 
{
  no strict;
  @ISA = qw(DynaLoader);
  __PACKAGE__->bootstrap($VERSION); #command table, etc.
}

sub new { return bless {}, shift }

#------------------------------------------------------------#
#---------------Configuration Directive Methods--------------#
#------------------------------------------------------------#

sub PerlINC ($$$) 
{
  my($cfg, $parms, $path) = @_;
  $cfg->{INC} = $path;
}

sub PerlVersion ($$@) 
{
  my($cfg, $parms, $name) = @_;
  $cfg->{'Files'}->{$name}++;
}


sub handler 
{
  my $r = shift;
  my $cfg = Apache::ModuleConfig->get($r, __PACKAGE__);

  
  if ($r->current_callback() eq "PerlCleanupHandler") 
  {
    # do clean up
    map { delete $INC{$_} } keys %{$cfg->{Files}};
    return OK;
  }
  
  
  # comment following line to have your requests see @INC
  local @INC; # dont mess with @main::INC. 
  unshift @INC, @{ $cfg->{'VINC'} };
  for (keys %{ $cfg->{'Files'} }) 
  {
    delete $INC{$_};
    #let mod_perl catch any error thrown here
    require $_;
  }
  
  return OK;
}

#------------------------------------------------------------#
#----------------Configuration Merging Routines--------------#
#------------------------------------------------------------#


sub DIR_CREATE
{
  my $self = shift->new();
  $self->{VINC} ||= []; #build @INC into here
  $self->{Files} ||= {};
  return $self;
}


sub DIR_MERGE
{
  my ($prt, $kid) = @_;

  my $new = {};

  # dont let kid overwrite with a blank value
  $new->{INC} = $kid->{INC} || $prt->{INC};
  # merge files to be reloaded
  %{ $new->{Files} } = (%{$prt->{Files}}, %{$kid->{Files}});

  # INC array gets built here.
  @{$new->{VINC}} = ($prt->{INC}, $kid->{INC});

  return bless $new, ;
}


1;
__END__

=head1 NAME

  Apache::PerlVINC - Allows versioning of modules among directories or v-hosts.

=head1 SYNOPSIS

#example httpd.conf:


<VirtualHost dave.domain.com>

  # include the module. this line must be here.
  PerlModule Apache::PerlVINC

  # set the include path
  PerlINC /home/dave/site/files/modules

  # make sure VINC reloads the modules
  PerlFixupHandler Apache::PerlVINC

  # optionally have VINC unload versioned modules
  PerlCleanupHandler Apache::PerlVINC


  # reloads Stuff::Things for all requests
  PerlVersion Stuff/Things.pm

  <Location /Spellcheck>
    SetHandler perl-script
    PerlHandler Spellcheck

    # reload version of this module found in PerlINC line
    PerlVersion Spellcheck.pm 
  </Location>

</VirtualHost>

<VirtualHost steve.domain.com>

  PerlModule Apache::PerlVINC
    
  <Location /Spellcheck>
    SetHandler perl-script
    PerlHandler Spellcheck
    PerlFixupHandler Apache::PerlVINC
    # only reload for requests in /Spellcheck

    PerlINC /home/steve/site/files/modules
    PerlVersion Spellcheck.pm  # makes PerlVINC load this version
  </Location>

</VirtualHost>


=head1 DESCRIPTION

With this module you can run two copies of a module without having to
worry about which version is being used. Suppose you have two C<VirtualHost>
or C<Location> that want to each use their own version of C<Spellcheck.pm>.
Durning the FixUp phase, C<Apache::PerlVINC> will tweak C<@INC> and reload 
C<Spellcheck>. Optionally, it will unload that version if you specify 
C<Apache::PerlVINC> as a PerlCleanUpHandler.

As you can guess, this module slows things down a little because it unloads and
reloads on a per-request basis. Hence, this module should only be used in a 
development environment, not a mission critical one.

=head1 DIRECTIVES

=over 4

=item PerlINC

Takes only one argument: the path to be prepended to C<@INC>. In v0.1, this was 
stored internally as an array. This is no longer the case. However, it still works
as expected in that subsequent calls to C<PerlINC> will not overwrite the previous
ones. They will both be prepended to C<@INC>. Note that C<@INC> is not changed for 
the entire request, so dont count on that path being in the C<@INC> for your scripts.

=item PerlVersion

This directives specifies the files you want reloaded. Depending on where this 
directive sits, files will be loaded (and perhaps unloaded). Ie. if this sits in 
a C<Location> section, the files will only be reloaded on requests to that location.
If this lies in a server section, all requests to the server or v-host will have 
these files reloaded. Again, this directive does not overwrite itself.

=back

=head1 BUGS

Sometimes, the server wont start and returns no errors. If you run with C<gdb>
you will see an error in C<ap_remove_module>. This happens with mod_perl 1.24
and maybe versions before that. The latest version of Apache::ExtUtils (v1.04) 
solves this problem by adding a call to ap_remove_module in the C<END> routine.

=head1 AUTHORS

  Doug MacEachern <dougm@pobox.com>
  Dave Moore <dave@epals.com>

=head1 COPYRIGHT

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
