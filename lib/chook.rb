### Copyright 2017 Pixar

###
###    Licensed under the Apache License, Version 2.0 (the "Apache License")
###    with the following modification; you may not use this file except in
###    compliance with the Apache License and the following modification to it:
###    Section 6. Trademarks. is deleted and replaced with:
###
###    6. Trademarks. This License does not grant permission to use the trade
###       names, trademarks, service marks, or product names of the Licensor
###       and its affiliates, except as required to comply with Section 4(c) of
###       the License and to reproduce the content of the NOTICE file.
###
###    You may obtain a copy of the Apache License at
###
###        http://www.apache.org/licenses/LICENSE-2.0
###
###    Unless required by applicable law or agreed to in writing, software
###    distributed under the Apache License with the above modification is
###    distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
###    KIND, either express or implied. See the Apache License for the specific
###    language governing permissions and limitations under the Apache License.
###
###

require 'ruby-jss'
require 'immutable-struct'

# The Chook module
#
module Chook

  # load in some sample JSON files, one per event type
  @sample_jsons = {}

  sample_json_dir = Pathname.new(__FILE__).parent + 'webhooks/data/sample_jsons'
  sample_json_dir.children.each do |jf|
    event = jf.basename.to_s.chomp(jf.extname).to_sym
    @sample_jsons[event] = jf.read
  end

  def self.sample_jsons
    @sample_jsons
  end

end # module

require 'configuration'
require 'jss/webhooks/event_objects'
require 'jss/webhooks/event'

Chook::Event::Handlers.load_handlers
