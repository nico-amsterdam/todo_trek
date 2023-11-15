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
import Awesomplete from '../vendor/awesomplete-v2020.min.js'
import AwesompleteUtil from '../vendor/awesomplete-util.min.js'

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

// <span id="list_country-autocomplete" forField="list_country" loadall="true" maxitems="8" minchars="0" prepop="true" url="https://restcountries.com/v2/all" value="name"></span>
Hooks.Autocomplete = {
    mounted() {
       const node = this.el, a = node.getAttribute.bind(node);
       if (a('forField') === undefined) throw new Error("Missing forField attribute.")
       let opts = {}, awesompleteOpts = {}
       const url = a('url'), loadall = a('loadall'),  prepop = a('prepop'), minChars = a('minChars'), maxItems = a('maxItems'), value = a('value')
       if (url) opts['url'] = url
       if (loadall) opts['loadall'] = (loadall === 'true')
       if (prepop) opts['prepop'] = (prepop === 'true')
       if (minChars) awesompleteOpts['minChars'] = Number(minChars)
       if (maxItems) awesompleteOpts['maxItems'] = Number(maxItems)
       if (value)    awesompleteOpts['data'] = function(rec, input) { return rec[value] || ''; }
       AwesompleteUtil.start('#' + a('forField'),
          opts,
          awesompleteOpts
       );
    }
}

Hooks.AutocompleteCopyValueToId = {
  mounted() {
    const node = this.el, a = node.getAttribute.bind(node), dataField = a('dataField'), field = a('field'), targetField = a('targetField')
    let target = a('target')
    if (field === undefined) throw new Error("Missing field attribute.")
    if (target === undefined && targetField === undefined) throw new Error("Missing target or targetField attribute.")
    if (targetField) target = '#' + targetField
    AwesompleteUtil.startCopy('#' + field, dataField, target);
  }
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
