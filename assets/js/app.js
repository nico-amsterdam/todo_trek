// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import Sortable from "../vendor/sortable"
import { attachAwesomplete, copyValueToId } from "phoenix_form_awesomplete"

let Hooks = {}

Hooks.LocalTime = {
  mounted(){ this.updated() },
  updated() {
    let dt = new Date(this.el.textContent)
    let options = {hour: "2-digit", minute: "2-digit", hour12: true, timeZoneName: "short"}
    this.el.textContent = `${dt.toLocaleString('en-US', options)}`
    this.el.classList.remove("invisible")
  }
}

Hooks.Sortable = {
  mounted(){
    let group = this.el.dataset.group
    let isDragging = false
    this.el.addEventListener("focusout", e => isDragging && e.stopImmediatePropagation())
    let sorter = new Sortable(this.el, {
      group: group ? {name: group, pull: true, put: true} : undefined,
      animation: 150,
      dragClass: "drag-item",
      ghostClass: "drag-ghost",
      onStart: e => isDragging = true, // prevent phx-blur from firing while dragging
      onEnd: e => {
        isDragging = false
        let params = {old: e.oldIndex, new: e.newIndex, to: e.to.dataset, ...e.item.dataset}
        this.pushEventTo(this.el, this.el.dataset["drop"] || "reposition", params)
      }
    })
  }
}

Hooks.SortableInputsFor = {
  mounted(){
    let group = this.el.dataset.group
    let sorter = new Sortable(this.el, {
      group: group ? {name: group, pull: true, put: true} : undefined,
      animation: 150,
      dragClass: "drag-item",
      ghostClass: "drag-ghost",
      handle: "[data-handle]",
      forceFallback: true,
      onEnd: e => {
        this.el.closest("form").querySelector("input").dispatchEvent(new Event("input", {bubbles: true}))
      }
    })
  }
}

// Do not add separator after selection in a multi select.
replaceRemoveLastSeparator = function(replaceText) { // cannot use arrow function, because access to 'this' is needed.
  // if multiple="@" then @ + space was added. Here the @ is removed.
  if (replaceText) replaceText = replaceText.substring(0, replaceText.length - 2) + ' ';
  this.input.value = replaceText;
}

// compare only the first word after the last @ sign of the input with the suggestions
convertInputFirstWordAfterAtSign = function(inputText) { // cannot use arrow function, because access to 'this' is needed.
  // do not compare if there is no @ in the input
  if (!this.input.value.includes('@')) return '';  
  // search till the first space
  if (inputText.includes(' ')) inputText = inputText.substring(0, inputText.indexOf(' '))
  return AwesompleteUtil.convertInput(inputText);
}

// don't show suggestions when there is no @ sign entered yet.
filterAfterAtSign = function(data, input) { // cannot use arrow function, because access to 'this' is needed.
  if (!this.input.value.includes('@')) return false;
  return AwesompleteUtil.filterContains(data, input);
}

// these functions and objects can be referenced by name in the autocomplete function components
const AU = AwesompleteUtil, customAwesompleteContext = {
  filterContains:   AU.filterContains  // the default, so it's not really needed here
, filterStartsWith: AU.filterStartsWith
, filterWords:      AU.filterWords
, filterOff:        AU.filterOff

, item:             AU.item
, itemContains:     AU.itemContains
, itemStartsWith:   AU.itemStartsWith
, itemMarkAll:      AU.itemMarkAll
, itemWords:        AU.itemWords

, replaceAtSign:      replaceRemoveLastSeparator
, convertInputAtSign: convertInputFirstWordAfterAtSign
, filterAtSign:       filterAfterAtSign

, listWithoutLabels: ['Ruby', 'Python']
, listWithLabels: [{ label: '<b>black</b>',  value: 'black' },{ label: '<i>red</i>', value: 'red' },{ label: 'blueish', value: 'blue' }]
}

Hooks.Autocomplete = {
   mounted() { attachAwesomplete(this.el, customAwesompleteContext, {}) }
}

// <span id="list_country-autocomplete" forField="list_country" loadall="true" maxitems="8" minchars="0" prepop="true" url="https://restcountries.com/v2/all" value="name"></span>

Hooks.AutocompleteCopyValueToId = {
  mounted() { copyValueToId(this.el) }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks: Hooks})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
