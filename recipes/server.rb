#
# Author:: AJ Christensen <aj@junglist.gen.nz>
# Author:: Dough MacEachern <dougm@vmware.com>
# Author:: Fletcher Nichol <fnichol@nichol.ca>
# Author:: Seth Chisamore <schisamo@opscode.com>
# Author:: Guilhem Lettron <guilhem.lettron@youscribe.com>
# Author:: Noah Kantrowitz <noah@coderanger.net>
#
# Copyright 2010, VMWare, Inc.
# Copyright 2012, Opscode, Inc.
# Copyright 2013, Youscribe.
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

chef_gem 'pry'
require 'pry'

jenkins node['jenkins']['server']['home']