(function () {
  'use strict';

  try {
    var storage = window.localStorage;
    if (!storage) {
      return;
    }

    var STORAGE_KEY = 'AriaNg.Options';
    var config = window.__ARIA2_WEB_WATCH__ || {};
    var rawOptions = storage.getItem(STORAGE_KEY);
    var options = {};

    if (rawOptions) {
      try {
        options = JSON.parse(rawOptions) || {};
      } catch (e) {
        console.warn('[aria2-web-watch] invalid existing AriaNg settings, recreating defaults', e);
        options = {};
      }
    }

    var changed = false;
    var ensureValue = function (key, value) {
      if (typeof value === 'undefined' || value === null) {
        return;
      }

      if (options[key] !== value) {
        options[key] = value;
        changed = true;
      }
    };
    var ensureDefault = function (key, value) {
      if (typeof options[key] === 'undefined') {
        options[key] = value;
        changed = true;
      }
    };
    var locationObject = window.location || document.location || {};
    var protocol = config.protocol || (locationObject.protocol === 'https:' ? 'https' : 'http');
    var host = config.rpcHost || locationObject.hostname || 'localhost';
    var port = config.rpcPort || locationObject.port;

    if (!port || port.length === 0) {
      port = protocol === 'https' ? '443' : '80';
    }

    ensureDefault('language', 'en');
    ensureDefault('theme', 'light');
    ensureDefault('title', '${downspeed}, ${upspeed} - ${title}');
    ensureDefault('titleRefreshInterval', 5000);
    ensureDefault('browserNotification', false);
    ensureDefault('browserNotificationSound', true);
    ensureDefault('browserNotificationFrequency', 'unlimited');
    ensureDefault('rpcAlias', '');
    ensureDefault('extendRpcServers', []);
    ensureDefault('webSocketReconnectInterval', 5000);
    ensureDefault('globalStatRefreshInterval', 1000);
    ensureDefault('downloadTaskRefreshInterval', 1000);
    ensureDefault('keyboardShortcuts', true);
    ensureDefault('swipeGesture', true);
    ensureDefault('dragAndDropTasks', true);
    ensureDefault('rpcListDisplayOrder', 'recentlyUsed');
    ensureDefault('afterCreatingNewTask', 'task-list');
    ensureDefault('removeOldTaskAfterRetrying', false);
    ensureDefault('confirmTaskRemoval', true);
    ensureDefault('includePrefixWhenCopyingFromTaskDetails', true);
    ensureDefault('showPiecesInfoInTaskDetailPage', 'le10240');
    ensureDefault('afterRetryingTask', 'task-list-downloading');
    ensureDefault('taskListIndependentDisplayOrder', false);
    ensureDefault('displayOrder', 'default:asc');
    ensureDefault('waitingTaskListPageDisplayOrder', 'default:asc');
    ensureDefault('stoppedTaskListPageDisplayOrder', 'default:asc');
    ensureDefault('fileListDisplayOrder', 'default:asc');
    ensureDefault('peerListDisplayOrder', 'default:asc');

    ensureValue('rpcHost', host);
    ensureValue('rpcPort', port);
    ensureValue('rpcInterface', config.rpcInterface || 'jsonrpc');
    var wsProtocol = (protocol === 'https') ? 'wss' : 'ws';
    ensureValue('protocol', protocol);
    ensureValue('httpMethod', 'POST');
    ensureValue('rpcProtocol', wsProtocol);
    ensureValue('rpcUseWebSocket', true);

    var secret = config.rpcSecretB64 || '';
    if (!secret && config.rpcSecret) {
      try {
        secret = window.btoa(config.rpcSecret);
      } catch (e) {
        console.warn('[aria2-web-watch] failed to encode rpc secret', e);
      }
    }
    if (secret) {
      var encodedSecret = secret;
      var isBase64 = function (value) {
        try {
          return window.btoa(window.atob(value)) === value;
        } catch (e) {
          return false;
        }
      };

      if (!isBase64(secret)) {
        encodedSecret = window.btoa(secret);
      }

      ensureValue('secret', encodedSecret);
    }

    if (changed) {
      storage.setItem(STORAGE_KEY, JSON.stringify(options));
      console.log('[aria2-web-watch] Applied AriaNg defaults for ' + host + ':' + port);
    }
  } catch (err) {
    console.warn('[aria2-web-watch] Failed to initialize AriaNg defaults', err);
  }
})();
