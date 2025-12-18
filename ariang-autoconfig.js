(function () {
  'use strict';

  try {
    if (!window.localStorage) {
      return;
    }

    var STORAGE_KEY = 'AriaNg.Options';
    var existing = window.localStorage.getItem(STORAGE_KEY);
    if (existing) {
      return;
    }

    var defaults = window.__ARIA2_WEB_WATCH__ || {};
    var locationObject = window.location || document.location || {};
    var protocol = defaults.protocol || (locationObject.protocol === 'https:' ? 'https' : 'http');
    var port = defaults.rpcPort || locationObject.port;

    if (!port || port.length === 0) {
      port = protocol === 'https' ? '443' : '80';
    }

    var options = {
      language: defaults.language || 'en',
      theme: defaults.theme || 'light',
      title: defaults.title || '${downspeed}, ${upspeed} - ${title}',
      titleRefreshInterval: defaults.titleRefreshInterval || 5000,
      browserNotification: !!defaults.browserNotification,
      browserNotificationSound: defaults.browserNotificationSound !== false,
      browserNotificationFrequency: defaults.browserNotificationFrequency || 'unlimited',
      rpcAlias: defaults.rpcAlias || '',
      rpcHost: defaults.rpcHost || locationObject.hostname || 'localhost',
      rpcPort: port,
      rpcInterface: defaults.rpcInterface || 'jsonrpc',
      protocol: protocol,
      httpMethod: defaults.httpMethod || 'POST',
      rpcRequestHeaders: defaults.rpcRequestHeaders || '',
      secret: defaults.rpcSecret ? window.btoa(defaults.rpcSecret) : '',
      extendRpcServers: defaults.extendRpcServers || [],
      webSocketReconnectInterval: defaults.webSocketReconnectInterval || 5000,
      globalStatRefreshInterval: defaults.globalStatRefreshInterval || 1000,
      downloadTaskRefreshInterval: defaults.downloadTaskRefreshInterval || 1000,
      keyboardShortcuts: defaults.keyboardShortcuts !== false,
      swipeGesture: defaults.swipeGesture !== false,
      dragAndDropTasks: defaults.dragAndDropTasks !== false,
      rpcListDisplayOrder: defaults.rpcListDisplayOrder || 'recentlyUsed',
      afterCreatingNewTask: defaults.afterCreatingNewTask || 'task-list',
      removeOldTaskAfterRetrying: !!defaults.removeOldTaskAfterRetrying,
      confirmTaskRemoval: defaults.confirmTaskRemoval !== false,
      includePrefixWhenCopyingFromTaskDetails: defaults.includePrefixWhenCopyingFromTaskDetails !== false,
      showPiecesInfoInTaskDetailPage: defaults.showPiecesInfoInTaskDetailPage || 'le10240',
      afterRetryingTask: defaults.afterRetryingTask || 'task-list-downloading',
      taskListIndependentDisplayOrder: !!defaults.taskListIndependentDisplayOrder,
      displayOrder: defaults.displayOrder || 'default:asc',
      waitingTaskListPageDisplayOrder: defaults.waitingTaskListPageDisplayOrder || 'default:asc',
      stoppedTaskListPageDisplayOrder: defaults.stoppedTaskListPageDisplayOrder || 'default:asc',
      fileListDisplayOrder: defaults.fileListDisplayOrder || 'default:asc',
      peerListDisplayOrder: defaults.peerListDisplayOrder || 'default:asc'
    };

    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(options));
    console.log('[aria2-web-watch] Initialized AriaNg defaults for ' + options.rpcHost + ':' + options.rpcPort);
  } catch (err) {
    console.warn('[aria2-web-watch] Failed to initialize AriaNg defaults', err);
  }
})();
