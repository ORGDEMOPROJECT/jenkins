#
# Author:: Doug MacEachern <dougm@vmware.com>
# Author:: Fletcher Nichol <fnichol@nichol.ca>
# Author:: Noah Kantrowitz <noah@coderanger.net>
#
# Copyright 2010, VMware, Inc.
# Copyright 2013, Balanced, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require File.expand_path('../jenkins', __FILE__)

class Chef
  class Resource::JenkinsProxy < Resource
    include Poise(Jenkins)
    actions(:install)

    attribute('', template: true)
    attribute(:listen_ports, kind_of: Array, default: lazy { node['jenkins']['proxy']['listen_ports'] })
    attribute(:hostname, kind_of: String, default: lazy { node['jenkins']['proxy']['hostname'] || node['fqdn'] })
    attribute(:ssl_enabled, equal_to: [true, false], default: lazy { node['jenkins']['proxy']['ssl_enabled'] })
    attribute(:ssl_redirect_http, equal_to: [true, false], default: lazy { node['jenkins']['proxy']['ssl_redirect_http'] })
    attribute(:ssl_listen_ports, kind_of: Array, default: lazy { node['jenkins']['proxy']['ssl_listen_ports'] })
    attribute(:ssl_path, kind_of: String, default: lazy { node['jenkins']['proxy']['ssl_path'] || ::File.join(parent.path, 'ssl') })
    attribute(:ssl_cert, kind_of: String)
    attribute(:ssl_key, kind_of: String)
    attribute(:ssl_cert_path, kind_of: String, default: lazy { node['jenkins']['proxy']['ssl_cert_path'] || ::File.join(ssl_path, 'jenkins.pem') })
    attribute(:ssl_key_path, kind_of: String, default: lazy { node['jenkins']['proxy']['ssl_key_path'] || ::File.join(ssl_path, 'jenkins.key') })

    def provider(arg=nil)
      if arg.kind_of?(String) || arg.kind_of?(Symbol)
        class_name = Mixin::ConvertToClassName.convert_to_class_name(arg.to_s)
        arg = Provider::JenkinsProxy.const_get(class_name) if Provider::JenkinsProxy.const_defined?(class_name)
      end
      super(arg)
    end

    def provider_for_action(*args)
      unless provider
        if node['jenkins']['proxy']['provider']
          provider(node['jenkins']['proxy']['provider'].to_sym)
        elsif default_provider = self.class.default_provider(node)
          provider(default_provider)
        else
          raise 'Unable to autodetect proxy provider, please specify one'
        end
      end
      super
    end

    def self.default_provider(node)
      # I would rather check if the cookbook is present, but this will have to do for now.
      # Checking run_context.cookbook_collection.include? fails because for solo it just blindly
      # loads everything in the cookbook_path.
      if node['recipes'].include?('apache2')
        :apache
      elsif node['recipes'].include?('nginx')
        :nginx
      end
    end
  end

  class Provider::JenkinsProxy < Provider
    include Poise

    def action_install
      converge_by("install a proxy server named #{Array(new_resource.hostname).join(', ')} for the Jenkins server at port #{new_resource.parent.port}") do
        notifying_block do
          install_server
          create_ssl_dir
          install_cert
          install_key
          configure_server
          enable_vhost
        end
        # If anything below changes, reload the service
        new_resource.notifies(:reload, run_context.resource_collection.find(service_resource))
      end
    end

    private

    def install_server
      raise NotImplementedError
    end

    def config_path
      raise NotImplementedError
    end

    def service_resource
      raise NotImplementedError
    end

    def create_ssl_dir
      if new_resource.ssl_enabled
        directory new_resource.ssl_path do
          owner 'root'
          group 'root'
          mode '700'
        end
      end
    end

    def install_cert
      if new_resource.ssl_enabled && new_resource.ssl_cert
        file new_resource.ssl_cert_path do
          owner 'root'
          group 'root'
          mode '600'
          content new_resource.ssl_cert
        end
      end
    end

    def install_key
      if new_resource.ssl_enabled && new_resource.ssl_key
        file new_resource.ssl_key_path do
          owner 'root'
          group 'root'
          mode '600'
          content new_resource.ssl_key
        end
      end
    end

    def configure_server
      # Only set the default source if nothing is currently set
      if !new_resource.source && !new_resource.content(nil, true)
        new_resource.source(default_source)
        new_resource.cookbook('jenkins')
      end
      file config_path do
        content new_resource.content
        owner 'root'
        group 'root'
        mode '600'
      end
    end

    def enable_vhost
      raise NotImplementedError
    end
  end

  class Provider::JenkinsProxy::Nginx < Provider::JenkinsProxy
    def install_server
      include_recipe 'nginx'
    end

    def config_path
      ::File.join(node['nginx']['dir'], 'sites-available','jenkins.conf')
    end

    def default_source
      'proxy_nginx.conf.erb'
    end

    def service_resource
      'service[nginx]'
    end

    def enable_vhost
      nginx_site 'jenkins.conf' do
        enable true
      end
    end
  end

  class Provider::JenkinsProxy::Apache < Provider::JenkinsProxy
    def install_server
      include_recipe 'apache2'
      include_recipe 'apache2::mod_rewrite'
      include_recipe 'apache2::mod_ssl' if new_resource.ssl_enabled

      apache_module 'proxy'
      apache_module 'proxy_http'
      apache_module 'vhost_alias'
    end

    def config_path
      ::File.join(node['apache']['dir'], 'sites-available','jenkins.conf')
    end

    def default_source
      'proxy_apache.conf.erb'
    end

    def service_resource
      'service[apache2]'
    end

    def enable_vhost
      apache_site 'jenkins.conf' do
        enable true
      end
    end
  end
end
