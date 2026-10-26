/* ==========================================================================
   RUBY UTILITY HUB - script.js
   Talks to the Ruby backend, shows a loading state, then renders the JSON
   answer that Ruby produced.

   Rules this file follows:
     * No maths happens here. Every value you see comes from Ruby.
     * Server data is written with textContent (never innerHTML), so a
       hostile string can never be turned into markup.
     * Anything the server rejects is shown as a readable error message.
   ========================================================================== */

(() => {
  'use strict';

  /* ---------------------------------------------------------------------
     Small DOM helper
     --------------------------------------------------------------------- */
  function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = String(text);
    return node;
  }

  function show(node, visible) {
    if (node) node.hidden = !visible;
  }

  /* ---------------------------------------------------------------------
     Client-side validation
     Fields marked `required` in the HTML must not be blank. The Ruby
     backend validates everything again, so this is only a courtesy check
     that saves a network request.
     --------------------------------------------------------------------- */
  function validate(form) {
    const fields = form.querySelectorAll('input[required]');

    for (const input of fields) {
      const label = form.querySelector(`label[for="${input.id}"]`);
      const name = label ? label.textContent.trim() : input.name;

      if (input.value.trim() === '') {
        input.setAttribute('aria-invalid', 'true');
        return `${name} is required.`;
      }
      input.removeAttribute('aria-invalid');
    }

    return null;
  }

  /* ---------------------------------------------------------------------
     The status chip in the hero must always tell the truth, so it is
     updated whenever a request succeeds or fails - not only at start-up.
     --------------------------------------------------------------------- */
  function setApiState(state, label) {
    const chip = document.getElementById('api-status');
    if (!chip) return;
    chip.dataset.state = state;
    chip.textContent = label;
  }

  /* ---------------------------------------------------------------------
     The request to the Ruby API
     Example: /api/circle_calculator?radius=5
     --------------------------------------------------------------------- */
  async function callApi(endpoint, params) {
    const url = `${endpoint}?${params.toString()}`;

    let response;
    try {
      response = await fetch(url, { headers: { Accept: 'application/json' } });
    } catch (networkError) {
      setApiState('unavailable', 'Ruby API not reachable');
      throw new Error(
        'Could not reach the Ruby backend. ' +
        'If you are running the project locally, start it with: ruby dev_server.rb'
      );
    }

    let data;
    try {
      data = await response.json();
    } catch (parseError) {
      // The server answered, but not with JSON - treat it as down.
      if (response.status >= 500) setApiState('unavailable', 'Ruby API not reachable');
      throw new Error(`The server answered with something other than JSON (HTTP ${response.status}).`);
    }

    if (!response.ok || data.ok === false) {
      if (response.status >= 500) setApiState('unavailable', 'Ruby API not reachable');
      throw new Error(data && data.error ? data.error : `Request failed (HTTP ${response.status}).`);
    }

    setApiState('connected', 'Ruby API connected');
    return data;
  }

  /* ---------------------------------------------------------------------
     Rendering the JSON payload produced by Ruby
     Shape: { ok, tool, summary?, rows?: [{label, value, mono?}], chips?: [] }
     --------------------------------------------------------------------- */
  function renderResult(container, data) {
    container.textContent = '';

    if (data.summary) {
      container.append(el('p', 'tool-output__summary', data.summary));
    }

    if (Array.isArray(data.rows) && data.rows.length > 0) {
      const list = el('dl', 'tool-output__rows');
      data.rows.forEach((row) => {
        list.append(el('dt', 'tool-output__label', row.label));
        list.append(
          el('dd', row.mono ? 'tool-output__value tool-output__value--mono' : 'tool-output__value', row.value)
        );
      });
      container.append(list);
    }

    if (Array.isArray(data.chips) && data.chips.length > 0) {
      const chips = el('div', 'tool-output__chips');
      data.chips.forEach((value) => chips.append(el('span', 'chip', value)));
      container.append(chips);
    }
  }

  /* ---------------------------------------------------------------------
     Submitting a tool card
     --------------------------------------------------------------------- */
  async function handleSubmit(event) {
    event.preventDefault();

    const form = event.currentTarget;
    const card = form.closest('.tool-card');
    if (!card) return;

    const output = card.querySelector('.tool-output');
    const errorBox = card.querySelector('.tool-error');
    const loading = card.querySelector('.tool-loading');
    const button = form.querySelector('button[type="submit"]');

    show(output, false);
    show(errorBox, false);
    if (errorBox) errorBox.textContent = '';

    const problem = validate(form);
    if (problem) {
      errorBox.textContent = problem;
      show(errorBox, true);
      return;
    }

    show(loading, true);
    if (button) {
      button.disabled = true;
      button.setAttribute('aria-busy', 'true');
    }

    try {
      // FormData must be converted to URLSearchParams: a raw FormData object
      // stringifies to "[object FormData]", which would send no parameters.
      const data = await callApi(form.dataset.endpoint, new URLSearchParams(new FormData(form)));
      renderResult(output, data);
      show(output, true);
    } catch (error) {
      errorBox.textContent = error.message || 'Something went wrong. Please try again.';
      show(errorBox, true);
    } finally {
      show(loading, false);
      if (button) {
        button.disabled = false;
        button.removeAttribute('aria-busy');
      }
    }
  }

  /* ---------------------------------------------------------------------
     Ping the API once so the hero can honestly report the connection
     --------------------------------------------------------------------- */
  function checkApi() {
    // callApi() updates the chip itself, on success and on failure.
    callApi('/api/odd_numbers', new URLSearchParams({ limit: '10' })).catch(() => {});
  }

  /* ---------------------------------------------------------------------
     Copy button for the "run locally" command block
     --------------------------------------------------------------------- */
  function wireCopyButtons() {
    document.querySelectorAll('[data-copy]').forEach((button) => {
      const original = button.textContent;

      button.addEventListener('click', async () => {
        try {
          await navigator.clipboard.writeText(button.dataset.copy);
          button.textContent = 'Copied!';
        } catch (clipboardError) {
          button.textContent = 'Press Ctrl+C';
        }
        window.setTimeout(() => {
          button.textContent = original;
        }, 1800);
      });
    });
  }

  /* ---------------------------------------------------------------------
     Start-up
     --------------------------------------------------------------------- */
  function init() {
    document.querySelectorAll('.tool-form[data-endpoint]').forEach((form) => {
      form.addEventListener('submit', handleSubmit);

      // Clear the "required" marker as soon as the visitor starts typing.
      form.querySelectorAll('input[required]').forEach((input) => {
        input.addEventListener('input', () => input.removeAttribute('aria-invalid'));
      });
    });

    wireCopyButtons();
    checkApi();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
