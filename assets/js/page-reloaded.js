document.querySelectorAll('[phx-update="ignore"] script').forEach(node => { node.setAttribute('data-script-ran', '')})
