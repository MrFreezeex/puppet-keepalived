require 'spec_helper_acceptance'

describe 'keepalived class' do
  context 'with default parameters' do
    pp = <<-EOS
    class { 'keepalived':
      sysconf_options => '-D --vrrp',
    }

    notify { "Keepalived version was: ${facts['keepalived_version']}":
      require => Class['keepalived'],
    }
    EOS

    it 'works with no error' do
      apply_manifest(pp, catch_failures: true)
    end
    it 'works idempotently' do
      pp2 = <<-EOS
      class { 'keepalived':
        sysconf_options => '-D --vrrp',
      }
      EOS
      apply_manifest(pp2, catch_changes: true)
    end
    it 'creates fact keepalived_version' do
      service_fact = apply_manifest(pp, catch_failures: true)
      expect(service_fact.output).to match %r{.*Keepalived version was: (\d.\d.\d).*}
    end

    describe package('keepalived') do
      it { is_expected.to be_installed }
    end

    describe file('/etc/keepalived/keepalived.conf') do
      it { is_expected.to be_file }
      its(:content) { is_expected.not_to contain('include ') }
    end
  end

  context 'on master with vrrp instance' do
    pp = <<-EOS
    class { 'keepalived':
      sysconf_options => '-D --vrrp',
    }

    keepalived::vrrp::instance { 'VI_50':
      interface         => $facts['networking']['primary'],
      state             => 'MASTER',
      virtual_router_id => 50,
      priority          => 101,
      auth_type         => 'PASS',
      auth_pass         => 'secret',
      virtual_ipaddress => [ '10.0.0.1/16' ],
    }
    EOS

    it 'works with no error' do
      apply_manifest(pp, catch_failures: true)
    end
    it 'works idempotently' do
      apply_manifest(pp, catch_changes: true)
    end

    describe file('/etc/keepalived/keepalived.conf') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match %r{.*MASTER.*} }
    end

    describe service('keepalived') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    # Works around any timing issues
    it 'has acquired the ip' do
      ip_result = shell('sleep 10; ip addr')
      expect(ip_result.stdout).to match %r{.*inet 10\.0\.0\.1/16 .*}
    end
  end

  context 'on master with globalconf' do
    pp = <<-EOS
    class { 'keepalived':
      sysconf_options => '-D --vrrp',
    }
    class { 'keepalived::global_defs':
      notification_email => 'nospan@example.com',
    }
    EOS

    it 'works with no error' do
      apply_manifest(pp, catch_failures: true)
    end
    it 'works idempotently' do
      apply_manifest(pp, catch_changes: true)
    end

    describe file('/etc/keepalived/keepalived.conf') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to contain('notification_email').from('global_defs').to('nospan@example.com') }
    end
  end

  context 'with unmanaged external config' do
    pp = <<-EOS
    file { '/etc/keepalived/myconfig.conf':
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => '',
      notify  => Class['keepalived::service']
    }

    class { 'keepalived':
      include_external_conf_files => ['/etc/keepalived/myconfig.conf'],
      sysconf_options             => '-D --vrrp',
    }
    EOS

    it 'works with no error' do
      apply_manifest(pp, catch_failures: true)
    end
    it 'works idempotently' do
      apply_manifest(pp, catch_changes: true)
    end

    describe file('/etc/keepalived/keepalived.conf') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to contain('include /etc/keepalived/myconfig.conf') }
    end
  end
end
