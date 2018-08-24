require_relative "../../../test/test_helper.rb"

require "yast2/systemd/unit"
require "yast2/systemd/unit_properties"
require "yast2/systemd/service"
require "yast2/systemd/socket"
require "yast2/systemd/target"

SYSTEMD_DATA_PATH = File.expand_path("data", __dir__)

# Find a Term in given content
#
# @param content [Yast::Term] the content in which perform the search
# @param type [Symbol] wanted Term type
# @param id [Symbol] wanted Term id
#
# @return [Yast::Term, nil] a Term when found; nil otherwise
def find_term(content, type, id)
  content.nested_find do |term|
    next unless term.is_a?(Yast::Term) && term.value == type

    term.params.any? { |i| i.is_a?(Yast::Term) && i.params == [id] }
  end
end

module SystemctlStubs
  def stub_systemctl(unit)
    case unit
    when :socket
      stub_socket_unit_files
      stub_socket_units
    when :service
      stub_service_unit_files
      stub_service_units
    when :target
      stub_target_unit_files
      stub_target_units
    end
    stub_execute
  end

  def stub_execute(success: true)
    allow(Yast2::Systemctl).to receive(:execute).and_return(
      OpenStruct.new(
        stdout: "success",
        stderr: (success ? "" : "failure"),
        exit:   (success ? 0  : 1)
      )
    )
  end

  def stub_socket_unit_files
    allow(Yast2::Systemctl).to receive(:list_unit_files).and_return(<<LIST
iscsid.socket                disabled
avahi-daemon.socket          enabled
cups.socket                  enabled
dbus.socket                  static
dm-event.socket              disabled
LIST
    )
  end

  def stub_service_unit_files
    allow(Yast2::Systemctl).to receive(:list_unit_files).and_return(<<LIST
single.service                             masked
smartd.service                             disabled
smb.service                                disabled
sshd.service                               enabled
sssd.service                               enabled
startpreload.service                       masked
LIST
    )
  end

  def stub_target_unit_files
    allow(Yast2::Systemctl).to receive(:list_unit_files).and_return(<<LIST
graphical.target          enabled
halt.target               disabled
hibernate.target          static
sleep.target              static
initrd-root-fs.target     static
initrd.target             static
kexec.target              disabled
multi-user.target         disabled
LIST
    )
  end

  def stub_service_units
    allow(Yast2::Systemctl).to receive(:list_units).and_return(<<LIST
rsyslog.service                       loaded active   running System Logging Service
scsidev.service                       not-found inactive dead    scsidev.service
sendmail.service                      not-found inactive dead    sendmail.service
sshd.service                          loaded active   running OpenSSH Daemon
sssd.service                          loaded active   running System Security Services Daemon
SuSEfirewall2.service                 loaded inactive dead    SuSEfirewall2 phase 2
LIST
    )
  end

  def stub_socket_units
    allow(Yast2::Systemctl).to receive(:list_units).and_return(<<LIST
iscsid.socket                loaded active   listening Open-iSCSI iscsid Socket
avahi-daemon.socket          loaded active   running   Avahi mDNS/DNS-SD Stack Activation Socket
cups.socket                  loaded inactive dead      CUPS Printing Service Sockets
dbus.socket                  loaded active   running   D-Bus System Message Bus Socket
dm-event.socket              loaded inactive dead      Device-mapper event daemon FIFOs
lvm2-lvmetad.socket          loaded inactive dead      LVM2 metadata daemon socket
pcscd.socket                 loaded active   listening PC/SC Smart Card Daemon Activation Socket
LIST
    )
  end

  def stub_target_units
    allow(Yast2::Systemctl).to receive(:list_units).and_return(<<LIST
getty.target           loaded active   active Login Prompts
graphical.target       loaded inactive dead   Graphical Interface
local-fs-pre.target    loaded active   active Local File Systems (Pre)
local-fs.target        loaded active   active Local File Systems
multi-user.target      loaded active   active Multi-User System
network-online.target  loaded inactive dead   Network is Online
network.target         loaded active   active Network
nss-lookup.target      loaded active   active Host and Network Name Lookups
LIST
    )
  end
end

module SystemdUnitStubs
  def stub_unit_command(success: true)
    allow_any_instance_of(Yast2::Systemd::Unit)
      .to receive(:command)
      .and_return(
        OpenStruct.new(
          stdout: "",
          stderr: (success ? "" : "failure"),
          exit:   (success ? 0  : 1)
        )
      )
  end
end

module SystemdSocketStubs
  include SystemctlStubs
  include SystemdUnitStubs

  def load_socket_properties(socket_name)
    OpenStruct.new(
      stdout: File.read(File.join(__dir__, "data", "#{socket_name}_socket_properties")),
      stderr: "",
      exit:   0
    )
  end

  def stub_sockets(socket: "iscsid")
    stub_unit_command
    stub_systemctl(:socket)
    properties = load_socket_properties(socket)
    allow_any_instance_of(Yast2::Systemd::UnitProperties)
      .to receive(:load_systemd_properties)
      .and_return(properties)
  end
end

module SystemdServiceStubs
  include SystemctlStubs
  include SystemdUnitStubs

  def stub_services(service: "sshd")
    stub_unit_command
    stub_systemctl(:service)
    properties = load_service_properties(service)
    allow_any_instance_of(Yast2::Systemd::UnitProperties)
      .to receive(:load_systemd_properties)
      .and_return(properties)
  end

  def load_service_properties(service_name)
    OpenStruct.new(
      stdout: File.read(File.join(__dir__, "data", "#{service_name}_service_properties")),
      stderr: "",
      exit:   0
    )
  end
end

module SystemdTargetStubs
  include SystemctlStubs
  include SystemdUnitStubs

  def stub_targets(target: "graphical")
    stub_unit_command
    stub_systemctl(:target)
    properties = load_target_properties(target)
    allow_any_instance_of(Yast2::Systemd::UnitProperties)
      .to receive(:load_systemd_properties)
      .and_return(properties)
  end

  def load_target_properties(target_name)
    OpenStruct.new(
      stdout: File.read(File.join(__dir__, "data", "#{target_name}_target_properties")),
      stderr: "",
      exit:   0
    )
  end
end
