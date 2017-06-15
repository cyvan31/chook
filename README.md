
# WebHooks for ruby-jss

- [Introduction](#introduction)
- [The Framework](#the-framework)
  - [Event Handlers](#event-handlers)
    - [Internal Handlers](#internal-handlers)
    - [External Handlers](#external-handlers)
  - [Putting it together](#putting-it-together)
  - [Events and Event objects](#events-and-event-objects)
- [The Server](#the-server)
- [Installing Chook into ruby-jss](#installing-jsswebhooks-into-ruby-jss)
- [TODOs](#todos)


## Introduction

Chook is a Ruby module which implements a framework for working with WebHook events
sent by the JSS, the core of [Jamf Pro](https://www.jamf.com/products/jamf-pro/),
a management tool for Apple devices.

Chook also provides a simple, sinatra-based http server, for handling those events,
and classes for sending simulated JSS WebHook events to a webhook server.

**You do not need to be a Ruby programmer to make use of this framework!**

The webhook handling server that comes with Chook can use "Event Handlers" written in
any language. See _Event Handlers_ and _The Server_ below for more info.

Chook is still in early development. While the basics seem to work,
there's much to do before it can be considered a released project.

While Chook integrates well with [ruby-jss](http://pixaranimationstudios.github.io/ruby-jss/index.html),
it's a separate tool and the two projects aren't dependent. However Chook
will become a requirement for [d3](http://pixaranimationstudios.github.io/depot3/index.html),
as the means by which d3 responds to Jamf Pro's PatchSoftwareTitleUpdated events.

For details about the JSS WebHooks API, and the JSON data it passes, please see
[Bryson Tyrrell's excellent
documentation.](https://unofficial-jss-api-docs.atlassian.net/wiki/display/JRA/Webhooks+API)

**Note:** when creating WebHooks in your JSS to be handled by the framework, you must
specify JSON in the 'Content Type' section. This framework doesn't support XML
formatted WebHook data.

## The Framework

The Chook framework abstracts WebHook events and their parts as Ruby
classes. When the JSON payload of a JSS WebHook POST request is passed into the
`Chook::Event.parse_event` method, an instance of the appropriate subclass
of `Chook::Event` is returned, for example
`Chook::ComputerInventoryCompletedEvent`

Each event instance contains these important attributes:

* **webhook:** A read-only instance of `Chook::Event::WebHook`
  representing the WebHook stored in the JSS which cause the POST request. This
  object has attributes matching those in the "webhook" dict. of the POSTed
  JSON.

* **event_object:** A read-only instance of a `Chook::EventObject::<Class>`
  representing the 'event object' that accompanies the event that triggered the
  WebHook. It comes from the 'object' dict of the POSTed JSON, and different
  events come with different objects attached. For example, the
  ComputerInventoryCompleted event comes with a "computer" object, containing
  data about the JSS computer that completed inventory.

  This is not full `JSS::Computer` object from the REST API, but rather a group
  of named attributes about that computer. At the moment the Chook
  framework makes no attempt to use the event object to look up the object in
  the API, but the handlers written for the event could easily do so if needed.

* **event_json:** The JSON content from the POST request, parsed into
  a Ruby hash with symbolized keys (meaning the JSON key "deviceName" becomes
  the symbol :deviceName)

* **raw_json:** A String containing the raw JSON from the POST
  request.

* **handlers:** An Array of custom plugins for working with the
  event. See _Event Handlers_, below.


### Event Handlers

A handler is a file containing code to run when a webhook event occurs. These
files are located in a specified directory, /Library/Application
Support/Chook/ by default, and are loaded at runtime. It's up to the Jamf
administrator to create these handlers to perform desired tasks. Each class of
event can have as many handlers as desired, all will be executed when the event's
`handle` method is called.

Handler files must begin with the name of the event they handle, e.g.
ComputerAdded, followed by: nothing, a dot, a dash, or an underscore. Handler
filenames are case-insensitive.

All of these filenames work as handlers for ComputerAdded events:

- ComputerAdded
- computeradded.sh
- COMPUTERAdded_notify_team
- Computeradded-update-ldap

There are two kinds of handlers:

#### Internal Handlers

These handlers are _non-executable_ files containing Ruby code. The code is
loaded at runtime and executed in the context of the Chook Framework when
called by an event.

Internal handlers must be defined as a [ruby code block](http://rubylearning.com/satishtalim/ruby_blocks.html) passed to the
`Chook.event_handler` method. The block must take one parameter, the
Chook::Event subclass instance being handled. Here's a simple example of
a handler for a Chook::ComputerAddedEvent

```ruby
Chook.event_handler do |event|
  cname = event.event_object.deviceName
  uname = event.event_object.realName
  puts "Computer '#{cname}' was just added to the JSS for user #{uname}."
end
```

In this example, the codeblock takes one parameter, which it expects to be
a Chook::ComputerAddedEvent instance, and uses it in the variable "event".
It then extracts the "deviceName" and "realName" values from the event_object
contained in the event, and uses them to send a message to stdout.

Internal handlers **must not** be executable files. Executability is how the
framework determines if a handler is internal or external.

#### External Handlers

External handlers are _executable_ files that are executed when called by an
event. They can be written in any language, but they must accept raw JSON on
their standard input. It's up to them to parse that JSON and react to it as
desired. In this case the Chook framework is merely a conduit for passing
the Posted JSON to the executable program.

Here's a simple example using bash and [jq](https://stedolan.github.io/jq/) to
do the same as the ruby example above:

```bash
#!/bin/bash
JQ="/usr/local/bin/jq"
while read line ; do JSON="$JSON $line" ; done
cname=`echo $JSON | "$JQ" -r '.event.deviceName'`
uname=`echo $JSON | "$JQ" -r '.event.realName'`
echo "Computer '${cname}' was just added to the JSS for user ${uname}."
```

External handlers **must** be executable files. Executability is how the
framework determines if a handler is internal or external.

See data/sample_handlers/RestAPIOperation-executable
for a more detailed bash example that handles RestAPIOperation events.

### Putting it together

Here's a commented sample of ruby code that uses the framework to process a
ComputerAdded event:

```ruby
# load in the framework
require 'chook'

# The framework comes with sample JSON files for each event type.
# In reality, a webserver would extract this from the data POSTed from the JSS
posted_json = Chook.sample_jsons[:ComputerAdded]

# Create Chook::Event::ComputerAddedEvent instance for the event
event = Chook::Event.parse_event posted_json

# Call the events #handle method, which will execute any ComputerAdded
# handlers that were in the Handler directory when the framework was loaded.
event.handle
```

Of course, you can use the framework without using the built-in #handle method,
and if you don't have any handlers in the directory, it won't do anything
anyway. Instead you are welcome to use the Event objects as desired in your own
Ruby code.

### Events and Event objects

Here are the Event classes supported by the framework and the  EventObject classes
they contain.
For details about the attributes of each EventObject, see [The Unofficial JSS API
Docs](https://unofficial-jss-api-docs.atlassian.net/wiki/display/JRA/Webhooks+API)

Each Event class is a subclass of `Chook::Event`, where all of their
functionality is defined.

The EventObject classes aren't subclasses, but are dynamically-defined members of
the `Chook::EventObjects` module.

| Event Classes | Event Object Classes |
| -------------- | ------------ |
| Chook::ComputerAddedEvent | Chook::EventObjects::Computer |
| Chook::ComputerCheckInEvent | Chook::EventObjects::Computer |
| Chook::ComputerInventoryCompletedEvent | Chook::EventObjects::Computer |
| Chook::ComputerPolicyFinishedEvent | Chook::EventObjects::Computer |
| Chook::ComputerPushCapabilityChangedEvent | Chook::EventObjects::Computer |
| Chook::JSSShutdownEvent | Chook::EventObjects::JSS |
| Chook::JSSStartupEvent | Chook::EventObjects::JSS |
| Chook::MobilDeviceCheckinEvent | Chook::EventObjects::MobileDevice |
| Chook::MobilDeviceCommandCompletedEvent | Chook::EventObjects::MobileDevice |
| Chook::MobilDeviceEnrolledEvent | Chook::EventObjects::MobileDevice |
| Chook::MobilDevicePushSentEvent | Chook::EventObjects::MobileDevice |
| Chook::MobilDeviceUnenrolledEvent | Chook::EventObjects::MobileDevice |
| Chook::PatchSoftwareTitleUpdateEvent | Chook::EventObjects::PatchSoftwareTitleUpdate |
| Chook::PushSentEvent | Chook::EventObjects::Push |
| Chook::RestAPIOperationEvent | Chook::EventObjects::RestAPIOperation |
| Chook::SCEPChallengeEvent | Chook::EventObjects::SCEPChallenge |
| Chook::SmartGroupComputerMembershipChangeEvent | Chook::EventObjects::SmartGroup |
| Chook::SmartGroupMobileDeviveMembershipChangeEvent | Chook::EventObjects::SmartGroup |


## The Server

Chook comes with a simple http server that uses the Chook framework
to handle all incoming webhook POST requests from the JSS via a single URL.

To use it you'll need to install the [sinatra](http://www.sinatrarb.com/
) ruby gem (`gem install sinatra`).

After that, just run the `jss-webhook-server` command located in the bin
directory for ruby-jss and then point your WebHooks at:
http://_my_hostname_/handle_webhook_event

It will then process all incoming webhook POST requests using whatever handlers
you have installed.

To automate it on a dedicated machine, just make a LaunchDaemon plist to run
that command and keep it running.

## Installing Chook

`gem install chook -n /usr/local/bin`. It will also install the dependencies 'sinatra' & 'immutable-struct'

Then fire up `irb` and `require jss/webhooks` to start playing around. (remember
the sample JSON strings available in `Chook.sample_jsons`)

OR

run `/usr/local/bin/chook` and point some WebHooks at your machine.


## TODOs

- Add SSL support to the server
- Better (any!) thread management for handlers
- Logging and Debug options
- handler reloading for individual, or all, Event subclasses
- Better YARD docs
- better namespace protection for internal handlers
- Use and improve the configuration stuff.
- write proper documentation beyond this README
- I'm sure there's more to do...