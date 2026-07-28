(() => {
  'use strict';

  const root = document.documentElement;
  if (!root.classList.contains('refined-loading')) return;

  const startedAt = Number(window.__refinedLoaderStartedAt) || Date.now();
  const minimumVisibleMs = 360;
  let revealed = false;

  const pendingAlerts = [];
  const originalAlert = window.jQuery && window.jQuery.suiAlert;
  const realtimeReadyTitles = new Set([
    '实时通道已建立',
    '實時通道已建立',
    'Realtime Channel Established',
    'Canal en Tiempo Real Establecido',
  ]);

  const isRealtimeReadyAlert = (options) =>
    options &&
    options.type === 'success' &&
    options.position === 'top-center' &&
    String(options.time) === '2' &&
    realtimeReadyTitles.has(String(options.title));

  const decorateAlerts = () => {
    document.querySelectorAll('.ui-alerts').forEach((container) => {
      container.setAttribute('aria-live', 'polite');
      container.setAttribute('aria-relevant', 'additions');
    });

    document.querySelectorAll('.ui-alerts .message').forEach((message) => {
      message.setAttribute(
        'role',
        message.classList.contains('error') ||
          message.classList.contains('negative') ||
          message.classList.contains('warning')
          ? 'alert'
          : 'status',
      );
    });
  };

  if (typeof originalAlert === 'function') {
    window.jQuery.suiAlert = function refinedAlert(options) {
      if (isRealtimeReadyAlert(options)) return undefined;

      if (root.classList.contains('refined-loading')) {
        pendingAlerts.push(options);
        return undefined;
      }

      const result = originalAlert.apply(this, arguments);
      decorateAlerts();
      return result;
    };
  }

  const flushAlerts = () => {
    if (typeof originalAlert !== 'function') return;
    pendingAlerts
      .splice(0)
      .filter((options) => !isRealtimeReadyAlert(options))
      .forEach((options) => originalAlert.call(window.jQuery, options));
    decorateAlerts();
  };

  const reveal = () => {
    if (revealed) return;
    revealed = true;
    window.clearTimeout(window.__refinedLoaderFallback);

    const elapsed = Date.now() - startedAt;
    window.setTimeout(() => {
      const loader = document.getElementById('refined-page-loader');
      root.classList.add('refined-ready');
      root.classList.remove('refined-loading');
      if (loader) {
        loader.classList.add('is-leaving');
        loader.setAttribute('aria-hidden', 'true');
      }
      window.setTimeout(() => {
        if (loader) loader.remove();
        flushAlerts();
        window.dispatchEvent(new CustomEvent('refined:ready'));
      }, 260);
    }, Math.max(0, minimumVisibleMs - elapsed));
  };

  const afterFirstVueRender = () => {
    if (revealed) return;
    const app = document.getElementById('app');
    const content = document.querySelector('.nb-container > .ui.container');
    if (!app || !content) {
      window.setTimeout(afterFirstVueRender, 16);
      return;
    }

    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(reveal);
    });
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', afterFirstVueRender, { once: true });
  } else {
    afterFirstVueRender();
  }

  window.setTimeout(reveal, 7500);
})();
