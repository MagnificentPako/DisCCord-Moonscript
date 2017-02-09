----------------------------------
--  File: main.moon
----------------------------------
import require from dofile "fix.lua"
import AsyncHTTPQueue from require "http"
import sort from table

W,H = term.getSize!
JSON = require "json"
httpQueue = AsyncHTTPQueue!

local updateTimerID

Manager = Application(1,1,W,H)\set {
  terminatable: true
  colour: colours.white
  backgroundColour: colours.grey
}

Manager\importFromTML "markup/master.tml"

data =
  servers: {}
  server: ""
  channel: ""
  lastMessages: {}
  channels: {}
  channelsOpen: false

app =
  masterTheme: Theme.fromFile "masterTheme", "styles/master.theme"
  pages: Manager\query"PageContainer".result[1]
  serverSelector: Manager\query"Dropdown#serverSelector".result[1]
  serverUsername: Manager\query"Input#usernameInput".result[1]
  channelsContainer: Manager\query"ScrollContainer#channels".result[1]
  messageContainer: Manager\query"ScrollContainer#messages".result[1]

Manager\addTheme app.masterTheme

httpQueue\get "servers", (content) ->
  content = JSON.parse(content)
  data.servers = content
  for k,v in pairs data.servers
    app.serverSelector\addOption v, v

updateMessages = ->
  httpQueue\get "receive/" .. data.server .. "/" .. data.channel, (content) ->
    lastMessages = JSON.parse content
    sort lastMessages, (a,b) -> a.timestamp < b.timestamp
    data.lastMessages = lastMessages
    app.messageContainer\clearNodes!
    shift = 0
    for k,v in pairs data.lastMessages
      author = Label(v.author..":",1,k+shift)\set {
        colour: colors.cyan
      }
      message = TextContainer(v.content, 1, k+shift+1, 49, 3)\set {
        backgroundColour: colors.black
      }
      app.messageContainer\addNode author
      app.messageContainer\addNode message
      shift += 3

updateChannels = ->
  httpQueue\get "server/" .. data.server .. "/channels", (content) ->
    content = JSON.parse content
    data.channels = content
    app.channelsContainer\clearNodes!
    for k,v in pairs data.channels
      button = Button("#" .. v)\set{
        height: 3
        width: 10
        horizontalAlign: "centre"
        verticalAlign: "centre"
        X: 1
        Y: 1 + ((k-1) * 3)
      }
      button\on "trigger", =>
        data.channel = v
        updateMessages!
      app.channelsContainer\addNode button


Manager\query"#serverNextButton"\on "trigger", =>
  selectedServer = app.serverSelector\getSelectedValue!
  selectedUsername = app.serverUsername.value
  if selectedServer and #selectedUsername > 0
    data.server = selectedServer
    data.username = selectedUsername
    updateChannels!
    app.pages\selectPage "chat"

Manager\query"#chatBackButton"\on "trigger", =>
  data.server = ""
  data.channel = ""
  app.pages\selectPage "serverSelect"

Manager\query"#toggleChannels"\on "trigger", =>
  data.channelsOpen = not data.channelsOpen
  self.text = data.channelsOpen and "<" or ">"
  Manager\query"#channelsContainer".result[1]\animate "animateChannelContainer",
                                                      "X",
                                                      data.channelsOpen and 1 or -8,
                                                      0.3,
                                                      data.channelsOpen and "inCubic" or "outCubic",
                                                      ->

Manager\query"#chatInput"\on "trigger", (value, selected) =>
  msg = value
  self.value = ""
  cont = JSON.stringify {
    user: data.username
    content: msg
  }
  httpQueue\post "send/" .. data.server .. "/" .. data.channel, cont, ->

app.pages\selectPage "serverSelect"


updateTimerID = os.startTimer 1
Manager\addThread Thread ->
  while true
    evt = {coroutine.yield!}
    if evt[1] == "timer" and evt[2] == updateTimerID
      if app.server != "" and app.channel != "" then
        updateMessages!
      updateTimerID = os.startTimer 2

Manager\addThread httpQueue\startRequestsThread!
Manager\addThread httpQueue\handleResponsesThread!

Manager\start!
