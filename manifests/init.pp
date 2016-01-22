# Author: Cody Herriges
# Pulls a selection of packages from a full Centos mirror and
# drops the packages into a requested location on the local machine
# if any packages are updated it then runs createrepo to generate
# a local yum repo.  The local repos are meant to allow PuppetMaster
# trainings to be ran in the event that internet connectivity is an
# issue.
#
# All package patterns in each local repo need to currently be with in the
# same resource.  This is due to the method of retrieving and cleaning
# up packages; each resource declaration is going to issues a `rsync
# --delete` with means that you will only get packages from the final
# resource that runs.  Suboptimal, yes and I think I am going to solve
# this with a ruby manifest at some point.
#
# Example:
#   pkgsync { "base_pkgs":
#     pkglist  => "httpd*\nperl-DBI*\nlibart_lgpl*\napr*\nruby-rdoc*\nntp*\n",
#     repopath => "/var/yum/mirror/centos/6/os/$::architecture",
#     source   => "::centos/6/os/$::architecture/CentOS/",
#     notify   => Repobuild["base"]
#   }
#
#   repobuild { "base":
#     repopath => "${base}/mirror/centos/6/os/$::architecture",
#   }

class localrepo {

  $base = "/var/yum"

  $directories = [ "${base}",
                   "${base}/mirror",
                   "${base}/mirror/epel",
                   "${base}/mirror/epel/6",
                   "${base}/mirror/epel/6/local",
                   "${base}/mirror/epel/7",
                   "${base}/mirror/epel/7/local",
                   "${base}/mirror/centos",
                   "${base}/mirror/centos/6",
                   "${base}/mirror/centos/6/os",
                   "${base}/mirror/centos/6/updates",
                   "${base}/mirror/centos/6/extras", ]
                   "${base}/mirror/centos/7",
                   "${base}/mirror/centos/7/os",
                   "${base}/mirror/centos/7/updates",
                   "${base}/mirror/centos/7/extras", ]

  File { mode => '644', owner => root, group => root }

  include localrepo::packages

  file { $directories:
    ensure => directory,
    recurse => true,
  }

  # Cache for both centos 7 and 32bit centos 6
  $os_info = [{'release' => '6','arch' => 'i386'},
              {'release' => '7','arch' => 'x86_64'}]
  $os_info.each |$info| {

    ## Build the "base" repo
    localrepo::pkgsync { "base_pkgs_${info['arch']}":
      pkglist  => epp("localrepo/base_pkgs.epp",{'release' => $info['release']},
      repopath => "${base}/mirror/centos/${info['release']}/os/${info['arch']}",
      syncer   => "yumdownloader",
      source   => "base",
      notify   => Localrepo::Repobuild["base_local_${info['arch']}"],
    }

    localrepo::repobuild { "base_local_${info['arch']}":
      repopath => "${base}/mirror/centos/${info['release']}/os/${info['arch']}",
      require  => Class['localrepo::packages'],
      notify   => Exec["makecache"],
    }
    
    ## Build the "extras" repo
    localrepo::pkgsync { "extras_pkgs_${info['arch']}":
      pkglist  => epp("localrepo/extras_pkgs.epp",{'release' => $info['release']},
      repopath => "${base}/mirror/centos/${info['release']}/extras/${info['arch']}",
      syncer   => "yumdownloader",
      source   => "base",
      notify   => Localrepo::Repobuild["extras_local_${info['arch']}"],
    }

    localrepo::repobuild { "extras_local_${info['arch']}":
      repopath => "${base}/mirror/centos/${info['release']}/extras/${info['arch']}",
      require  => Class['localrepo::packages'],
      notify   => Exec["makecache"],
    }

    ## Build the "updates" repo
    localrepo::pkgsync { "updates_pkgs_${info['arch']}":
      pkglist  => epp("localrepo/updates_pkgs.epp",{'release' => $info['release']},
      repopath => "${base}/mirror/centos/${info['release']}/updates/${info['arch']}",
      syncer   => "yumdownloader",
      source   => "base",
      notify   => Localrepo::Repobuild["updates_local_${info['arch']}"],
    }

    localrepo::repobuild { "updates_local_${info['arch']}":
      repopath => "${base}/mirror/centos/${info['release']}/updates/${info['arch']}",
      require  => Class['localrepo::packages'],
      notify   => Exec["makecache"],
    }

    ## Build the "epel" repo
    localrepo::pkgsync { "epel_pkgs_${info['arch']}":
      pkglist  => epp("localrepo/epel_pkgs.epp",{'release' => $info['release']},
      repopath => "${base}/mirror/epel/${info['release']}/local/${info['arch']}",
      syncer   => "yumdownloader",
      source   => "epel",
      notify   => Localrepo::Repobuild["epel_local_${info['arch']}"],
      require  => Class['epel']
    }

    localrepo::repobuild { "epel_local_${info['arch']}":
      repopath => "${base}/mirror/epel/${info['release']}/local/${info['arch']}",
      require  => Class['localrepo::packages'],
      notify   => Exec["makecache"],
    }
  }

  exec { "makecache":
    command     => "yum makecache",
    path        => "/usr/bin",
    refreshonly => true,
    user        => root,
    group       => root,
  }
}
