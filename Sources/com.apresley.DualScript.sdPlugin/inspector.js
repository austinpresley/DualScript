const DEFAULT_LANGUAGE = 'AppleScript';
const SAVE_DEBOUNCE_MS = 180;
const VALIDATION_DEBOUNCE_MS = 420;

const TRIGGERS = {
    down: {
        test: 'testDown',
        validate: 'validateDown'
    },
    up: {
        test: 'testUp',
        validate: 'validateUp'
    }
};

const PHASES = {
    down: {
        label: 'Key Down',
        inputId: 'scriptDown',
        highlightId: 'highlightDown',
        gutterId: 'gutterDown',
        placeholderId: 'placeholderDown',
        feedbackId: 'feedbackDown',
        metricsId: 'metricsDown',
        validateId: 'validateDown',
        runId: 'testDown'
    },
    up: {
        label: 'Key Up',
        inputId: 'scriptUp',
        highlightId: 'highlightUp',
        gutterId: 'gutterUp',
        placeholderId: 'placeholderUp',
        feedbackId: 'feedbackUp',
        metricsId: 'metricsUp',
        validateId: 'validateUp',
        runId: 'testUp'
    }
};

const PLACEHOLDERS = {
    AppleScript: {
        down: 'tell application "Music"\n    playpause\nend tell',
        up: 'tell application "Music"\n    pause\nend tell'
    },
    JavaScript: {
        down: 'const music = Application("Music");\nmusic.playpause();',
        up: 'const music = Application("Music");\nmusic.pause();'
    }
};

const APPLESCRIPT_KEYWORDS = [
    'activate', 'and', 'as', 'considering', 'copy', 'delay', 'do', 'else', 'end', 'false',
    'global', 'if', 'ignoring', 'in', 'local', 'my', 'not', 'of', 'on', 'or', 'property',
    'repeat', 'return', 'script', 'set', 'tell', 'then', 'timeout', 'to', 'true', 'try',
    'whose', 'with', 'without'
];

const APPLESCRIPT_BUILTINS = [
    'current application', 'do shell script', 'missing value', 'quoted form of'
];

const JAVASCRIPT_KEYWORDS = [
    'await', 'break', 'case', 'catch', 'const', 'continue', 'default', 'else', 'false',
    'finally', 'for', 'function', 'if', 'let', 'new', 'null', 'return', 'switch', 'throw',
    'true', 'try', 'undefined', 'var', 'while'
];

const JAVASCRIPT_BUILTINS = [
    'Application', 'Application.currentApplication', 'JSON.stringify'
];

const state = {
    action: '',
    context: '',
    activePhase: 'down',
    socket: null,
    saveTimer: null,
    validationTimers: {
        down: null,
        up: null
    },
    validationRequestIds: {
        down: 0,
        up: 0
    },
    errorLines: {
        down: null,
        up: null
    }
};

function connectElgatoStreamDeckSocket(inPort, inUUID, inRegisterEvent, inInfo, inActionInfo) {
    const actionInfo = JSON.parse(inActionInfo);
    const savedSettings = (actionInfo.payload && actionInfo.payload.settings) || {};

    state.action = actionInfo.action;
    state.context = actionInfo.context || inUUID;

    initializeEditors();
    hydrateForm(normalizeSettings(savedSettings));
    setStatus('neutral', 'Connected. Settings save automatically.');
    openSocket(inPort, inUUID, inRegisterEvent, savedSettings);
}

function initializeEditors() {
    Object.keys(PHASES).forEach((phase) => {
        const refs = getPhaseRefs(phase);

        refs.input.addEventListener('input', () => handleEditorInput(phase));
        refs.input.addEventListener('scroll', () => syncEditorScroll(phase));
        refs.input.addEventListener('keydown', (event) => handleEditorKeydown(phase, event));
        refs.validateButton.addEventListener('click', () => triggerValidation(phase, true));
        refs.runButton.addEventListener('click', () => runTest(phase));
    });

    document.querySelectorAll('[data-phase-tab]').forEach((button) => {
        button.addEventListener('click', () => setActivePhase(button.dataset.phaseTab));
    });

    document.getElementById('language').addEventListener('change', handleLanguageChange);
}

function openSocket(port, uuid, registerEvent, savedSettings) {
    state.socket = new WebSocket(`ws://127.0.0.1:${port}`);

    state.socket.onopen = () => {
        send({
            event: registerEvent,
            uuid
        });

        if (needsMigration(savedSettings)) {
            persistSettings('Migrated legacy settings into Key Down.');
        }

        triggerValidation('down', false);
        triggerValidation('up', false);
    };

    state.socket.onmessage = (event) => {
        let message;

        try {
            message = JSON.parse(event.data);
        } catch (_error) {
            return;
        }

        if (message.event !== 'sendToPropertyInspector' || message.context !== state.context) {
            return;
        }

        handlePluginMessage(message.payload || {});
    };

    state.socket.onerror = () => {
        setStatus('error', 'The property inspector could not connect to Stream Deck.');
    };
}

function handlePluginMessage(payload) {
    if (payload.type === 'validationResult') {
        const phase = payload.phase;
        if (!PHASES[phase]) {
            return;
        }

        const expectedRequestId = String(state.validationRequestIds[phase]);
        if (String(payload.requestID || '') !== expectedRequestId) {
            return;
        }

        applyValidationResult(phase, payload);
        return;
    }

    if (payload.type === 'executionResult') {
        const phase = payload.phase;
        if (!PHASES[phase]) {
            return;
        }

        const location = typeof payload.rangeLocation === 'number' ? payload.rangeLocation : null;
        const source = getPhaseRefs(phase).input.value;
        const message = decorateMessageWithLine(source, location, payload.message || '');
        setPhaseFeedback(phase, payload.success ? 'success' : 'error', message, locationToLine(source, location));
        setStatus(payload.success ? 'success' : 'error', message);
    }
}

function normalizeSettings(savedSettings) {
    const normalized = {
        language: savedSettings.language === 'JavaScript' ? 'JavaScript' : DEFAULT_LANGUAGE,
        scriptDown: '',
        scriptUp: typeof savedSettings.scriptUp === 'string' ? savedSettings.scriptUp : ''
    };

    if (typeof savedSettings.scriptDown === 'string' && savedSettings.scriptDown.length > 0) {
        normalized.scriptDown = savedSettings.scriptDown;
    } else if (typeof savedSettings.scriptText === 'string' && savedSettings.scriptText.length > 0) {
        normalized.scriptDown = savedSettings.scriptText;
    } else if (typeof savedSettings.script === 'string' && savedSettings.script.length > 0) {
        normalized.scriptDown = savedSettings.script;
    }

    return normalized;
}

function needsMigration(savedSettings) {
    const hasLegacySingleScript = typeof savedSettings.scriptText === 'string' || typeof savedSettings.script === 'string';
    const isMissingScriptDown = !(typeof savedSettings.scriptDown === 'string' && savedSettings.scriptDown.length > 0);
    return hasLegacySingleScript && isMissingScriptDown;
}

function hydrateForm(settings) {
    document.getElementById('language').value = settings.language;
    getPhaseRefs('down').input.value = settings.scriptDown;
    getPhaseRefs('up').input.value = settings.scriptUp;
    updatePlaceholders(settings.language);
    syncAllEditors();
    setActivePhase(settings.scriptDown.trim() ? 'down' : settings.scriptUp.trim() ? 'up' : 'down');
}

function handleLanguageChange(event) {
    const language = event.target.value;
    updatePlaceholders(language);
    syncAllEditors();
    queueSave();
    triggerValidation('down', false);
    triggerValidation('up', false);
}

function collectSettings() {
    return {
        language: document.getElementById('language').value,
        scriptDown: getPhaseRefs('down').input.value,
        scriptUp: getPhaseRefs('up').input.value
    };
}

function updatePlaceholders(language) {
    const active = PLACEHOLDERS[language] || PLACEHOLDERS[DEFAULT_LANGUAGE];
    getPhaseRefs('down').placeholder.textContent = active.down;
    getPhaseRefs('up').placeholder.textContent = active.up;
}

function syncAllEditors() {
    Object.keys(PHASES).forEach((phase) => syncEditor(phase));
}

function setActivePhase(phase) {
    if (!PHASES[phase]) {
        return;
    }

    state.activePhase = phase;

    document.querySelectorAll('[data-phase-tab]').forEach((button) => {
        const isActive = button.dataset.phaseTab === phase;
        button.classList.toggle('is-active', isActive);
        button.setAttribute('aria-selected', String(isActive));
    });

    document.querySelectorAll('[data-phase-panel]').forEach((panel) => {
        panel.classList.toggle('is-hidden', panel.dataset.phasePanel !== phase);
    });
}

function handleEditorInput(phase) {
    syncEditor(phase);
    queueSave();
    triggerValidation(phase, false);
}

function handleEditorKeydown(phase, event) {
    const input = getPhaseRefs(phase).input;

    if (event.key === 'Tab') {
        event.preventDefault();
        input.setRangeText('    ', input.selectionStart, input.selectionEnd, 'end');
        handleEditorInput(phase);
        return;
    }

    if (event.key === 'Enter') {
        const settings = collectSettings();
        const currentLine = input.value.slice(0, input.selectionStart).split('\n').pop();
        const indent = (currentLine.match(/^\s*/) || [''])[0];
        const extraIndent = shouldIncreaseIndent(currentLine, settings.language) ? '    ' : '';

        event.preventDefault();
        input.setRangeText(`\n${indent}${extraIndent}`, input.selectionStart, input.selectionEnd, 'end');
        handleEditorInput(phase);
    }
}

function shouldIncreaseIndent(line, language) {
    const trimmed = line.trim();
    if (!trimmed) {
        return false;
    }

    if (language === 'JavaScript') {
        return /[{[(]\s*$/.test(trimmed);
    }

    return /^(tell\b|repeat\b|try\b|on\b.+|if\b.+\bthen)$/i.test(trimmed);
}

function syncEditor(phase) {
    const refs = getPhaseRefs(phase);
    const language = document.getElementById('language').value;
    const source = refs.input.value;

    refs.highlight.innerHTML = highlightSource(source, language);
    refs.placeholder.hidden = source.length > 0;
    renderLineNumbers(phase, source);
    updateMetrics(phase, source);
    syncEditorScroll(phase);
}

function syncEditorScroll(phase) {
    const refs = getPhaseRefs(phase);
    const translate = `translate(${-refs.input.scrollLeft}px, ${-refs.input.scrollTop}px)`;
    refs.highlight.style.transform = translate;
    refs.gutter.style.transform = `translateY(${-refs.input.scrollTop}px)`;
}

function renderLineNumbers(phase, source) {
    const refs = getPhaseRefs(phase);
    const lineCount = Math.max(1, source.split('\n').length);
    const errorLine = state.errorLines[phase];

    refs.gutter.innerHTML = Array.from({ length: lineCount }, (_value, index) => {
        const lineNumber = index + 1;
        const errorClass = lineNumber === errorLine ? ' is-error' : '';
        return `<span class="${errorClass.trim()}">${lineNumber}</span>`;
    }).join('');
}

function updateMetrics(phase, source) {
    const lines = Math.max(1, source.split('\n').length);
    const characters = source.length;
    getPhaseRefs(phase).metrics.textContent = `${lines} line${lines === 1 ? '' : 's'} • ${characters} char${characters === 1 ? '' : 's'}`;
}

function queueSave() {
    clearTimeout(state.saveTimer);
    setStatus('neutral', 'Saving settings…');
    state.saveTimer = window.setTimeout(() => persistSettings('Settings saved.'), SAVE_DEBOUNCE_MS);
}

function persistSettings(message) {
    send({
        event: 'setSettings',
        context: state.context,
        payload: collectSettings()
    });

    if (message) {
        setStatus('success', message);
    }
}

function triggerValidation(phase, immediate) {
    const settings = collectSettings();
    const source = phase === 'down' ? settings.scriptDown : settings.scriptUp;
    const issue = detectLocalIssue(source, settings.language);

    clearTimeout(state.validationTimers[phase]);

    if (!source.trim()) {
        setPhaseFeedback(phase, 'neutral', `${PHASES[phase].label} is empty.`, null);
        return;
    }

    if (issue) {
        setPhaseFeedback(phase, 'error', issue.message, issue.line);
    } else {
        setPhaseFeedback(phase, 'neutral', 'Compiling syntax…', null);
    }

    const validate = () => requestRemoteValidation(phase, settings);
    if (immediate) {
        validate();
    } else {
        state.validationTimers[phase] = window.setTimeout(validate, VALIDATION_DEBOUNCE_MS);
    }
}

function requestRemoteValidation(phase, settings) {
    state.validationRequestIds[phase] += 1;

    send({
        event: 'sendToPlugin',
        action: state.action,
        context: state.context,
        payload: {
            trigger: TRIGGERS[phase].validate,
            requestID: String(state.validationRequestIds[phase]),
            settings
        }
    });
}

function applyValidationResult(phase, payload) {
    const refs = getPhaseRefs(phase);
    const source = refs.input.value;
    const location = typeof payload.rangeLocation === 'number' ? payload.rangeLocation : null;
    const message = decorateMessageWithLine(source, location, payload.message || '');
    const line = locationToLine(source, location);
    setPhaseFeedback(phase, payload.success ? 'success' : 'error', message, line);
}

function runTest(phase) {
    const settings = collectSettings();
    persistSettings('');
    setPhaseFeedback(phase, 'neutral', `Running ${PHASES[phase].label}…`, null);
    setStatus('neutral', `Running ${PHASES[phase].label} test…`);

    send({
        event: 'sendToPlugin',
        action: state.action,
        context: state.context,
        payload: {
            trigger: TRIGGERS[phase].test,
            settings
        }
    });
}

function detectLocalIssue(source, language) {
    if (!source.trim()) {
        return null;
    }

    if (language === 'JavaScript') {
        try {
            // eslint-disable-next-line no-new, no-new-func
            new Function(source);
            return null;
        } catch (error) {
            return {
                message: `Possible JavaScript syntax issue: ${error.message}`,
                line: extractLineNumber(error)
            };
        }
    }

    return detectAppleScriptBlockIssue(source);
}

function detectAppleScriptBlockIssue(source) {
    const blockStack = [];
    const lines = source.split('\n');

    for (let index = 0; index < lines.length; index += 1) {
        const lineNumber = index + 1;
        const trimmed = lines[index].trim().toLowerCase();

        if (!trimmed || trimmed.startsWith('--')) {
            continue;
        }

        if (/^tell\b/.test(trimmed)) {
            blockStack.push({ type: 'tell', line: lineNumber });
        } else if (/^repeat\b/.test(trimmed)) {
            blockStack.push({ type: 'repeat', line: lineNumber });
        } else if (/^try\b/.test(trimmed)) {
            blockStack.push({ type: 'try', line: lineNumber });
        } else if (/^if\b.+\bthen$/.test(trimmed)) {
            blockStack.push({ type: 'if', line: lineNumber });
        } else if (/^on\b\s+/.test(trimmed)) {
            blockStack.push({ type: 'handler', line: lineNumber });
        } else if (/^end tell\b/.test(trimmed)) {
            if (!popBlock(blockStack, 'tell')) {
                return { message: 'Found "end tell" without a matching "tell".', line: lineNumber };
            }
        } else if (/^end repeat\b/.test(trimmed)) {
            if (!popBlock(blockStack, 'repeat')) {
                return { message: 'Found "end repeat" without a matching "repeat".', line: lineNumber };
            }
        } else if (/^end if\b/.test(trimmed)) {
            if (!popBlock(blockStack, 'if')) {
                return { message: 'Found "end if" without a matching multiline "if ... then".', line: lineNumber };
            }
        } else if (/^end try\b/.test(trimmed)) {
            if (!popBlock(blockStack, 'try')) {
                return { message: 'Found "end try" without a matching "try".', line: lineNumber };
            }
        } else if (/^end\b/.test(trimmed) && hasOpenHandler(blockStack)) {
            blockStack.pop();
        }
    }

    if (blockStack.length > 0) {
        const openBlock = blockStack[blockStack.length - 1];
        return {
            message: `Possible missing "end ${openBlock.type === 'handler' ? 'handler' : openBlock.type}" for block opened on line ${openBlock.line}.`,
            line: openBlock.line
        };
    }

    return null;
}

function popBlock(stack, type) {
    if (stack.length === 0) {
        return false;
    }

    const last = stack[stack.length - 1];
    if (last.type !== type) {
        return false;
    }

    stack.pop();
    return true;
}

function hasOpenHandler(stack) {
    return stack.length > 0 && stack[stack.length - 1].type === 'handler';
}

function extractLineNumber(error) {
    const match = String(error && error.stack || '').match(/<anonymous>:(\d+):\d+/);
    return match ? Number(match[1]) - 1 : null;
}

function decorateMessageWithLine(source, location, message) {
    const line = locationToLine(source, location);
    return line ? `Line ${line}: ${message}` : message;
}

function locationToLine(source, location) {
    if (typeof location !== 'number' || location < 0) {
        return null;
    }

    const bounded = Math.min(location, source.length);
    return source.slice(0, bounded).split('\n').length;
}

function highlightSource(source, language) {
    const raw = source || '';

    if (!raw.length) {
        return '&nbsp;';
    }

    const protectedTokens = [];
    let working = raw;

    const protections = language === 'JavaScript'
        ? [
            { regex: /\/\*[\s\S]*?\*\//g, className: 'comment' },
            { regex: /\/\/.*$/gm, className: 'comment' },
            { regex: /`(?:\\[\s\S]|[^`])*`/g, className: 'string' },
            { regex: /'(?:\\.|[^'\\])*'?/g, className: 'string' },
            { regex: /"(?:\\.|[^"\\])*"?/g, className: 'string' }
        ]
        : [
            { regex: /\(\*[\s\S]*?\*\)/g, className: 'comment' },
            { regex: /--.*$/gm, className: 'comment' },
            { regex: /"(?:[^"]|"")*"?/g, className: 'string' }
        ];

    protections.forEach((pattern) => {
        working = working.replace(pattern.regex, (match) => {
            const key = `@@${protectedTokens.length}@@`;
            protectedTokens.push({
                key,
                html: `<span class="token ${pattern.className}">${escapeHtml(match)}</span>`
            });
            return key;
        });
    });

    let html = escapeHtml(working).replace(/\t/g, '    ');
    html = highlightMatches(html, /\b\d+(?:\.\d+)?\b/g, 'number');

    if (language === 'JavaScript') {
        html = highlightKeywords(html, JAVASCRIPT_KEYWORDS, 'keyword');
        html = highlightPhrases(html, JAVASCRIPT_BUILTINS, 'builtin');
    } else {
        html = highlightKeywords(html, APPLESCRIPT_KEYWORDS, 'keyword');
        html = highlightPhrases(html, APPLESCRIPT_BUILTINS, 'builtin');
    }

    protectedTokens.forEach((token) => {
        html = html.split(token.key).join(token.html);
    });

    return raw.endsWith('\n') ? `${html}\n` : html;
}

function highlightKeywords(html, keywords, className) {
    const regex = new RegExp(`\\b(?:${keywords.join('|')})\\b`, 'gi');
    return highlightMatches(html, regex, className);
}

function highlightPhrases(html, phrases, className) {
    return phrases.reduce((accumulator, phrase) => {
        const regex = new RegExp(escapeRegExp(phrase), 'gi');
        return highlightMatches(accumulator, regex, className);
    }, html);
}

function highlightMatches(html, regex, className) {
    return html.replace(regex, (match) => `<span class="token ${className}">${match}</span>`);
}

function escapeHtml(value) {
    return value
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
}

function escapeRegExp(value) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function setPhaseFeedback(phase, kind, message, errorLine) {
    const refs = getPhaseRefs(phase);
    refs.feedback.textContent = message;
    refs.feedback.className = `feedback feedback-${kind}`;
    state.errorLines[phase] = errorLine || null;
    renderLineNumbers(phase, refs.input.value);
}

function getPhaseRefs(phase) {
    const config = PHASES[phase];
    return {
        input: document.getElementById(config.inputId),
        highlight: document.getElementById(config.highlightId),
        gutter: document.getElementById(config.gutterId),
        placeholder: document.getElementById(config.placeholderId),
        feedback: document.getElementById(config.feedbackId),
        metrics: document.getElementById(config.metricsId),
        validateButton: document.getElementById(config.validateId),
        runButton: document.getElementById(config.runId)
    };
}

function send(payload) {
    if (!state.socket || state.socket.readyState !== WebSocket.OPEN) {
        setStatus('error', 'Stream Deck is not connected yet.');
        return;
    }

    state.socket.send(JSON.stringify(payload));
}

function setStatus(kind, message) {
    const status = document.getElementById('status');
    status.textContent = message;
    status.className = `status status-${kind}`;
}
