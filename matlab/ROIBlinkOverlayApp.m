classdef ROIBlinkOverlayApp < matlab.apps.AppBase

% ROIBlinkOverlayApp  — GUI wrapper for overlayBlinkingROIs_onMean
%
% Drag-and-drop style file loading, W/L controls on the mean projection,
% calcium-kernel parameters, render settings and an Advanced panel.
%
% Usage:
%   ROIBlinkOverlayApp   % launch the app
%
% Requires: MATLAB R2019b+ with App Designer runtime (uifigure).
%           Image Processing Toolbox (im2double, imresize, prctile).
%           VideoWriter (built-in).
%
% How it works:
%   1. Load Fall.mat  → reads ops (ops.meanImg, ops.fs), iscell, stat.
%   2. Load spiketimes .mat → reads path1_phys.spiketimes (or spks / spiketimes).
%   3. Optionally override the mean image with a jpg/tif/png.
%   4. Adjust brightness / contrast / percentile clip on the preview.
%   5. Set kernel params, duration, speed, output filename.
%   6. Hit Preview (5 s) or Generate MP4.

    % ── App properties ──────────────────────────────────────────────────────
    properties (Access = private)

        % --- UI figure & major panels ---
        UIFigure            matlab.ui.Figure
        MainGrid            matlab.ui.container.GridLayout

        LeftPanel           matlab.ui.container.Panel
        LeftScroll          matlab.ui.container.GridLayout
        RightPanel          matlab.ui.container.Panel

        % --- File-load section ---
        FallSection         matlab.ui.container.Panel
        FallButton          matlab.ui.control.Button
        FallStatusLabel     matlab.ui.control.Label
        FallFilenameLabel   matlab.ui.control.Label
        FPSValueLabel       matlab.ui.control.Label

        SpikesButton        matlab.ui.control.Button
        SpikesStatusLabel   matlab.ui.control.Label
        SpikesFilenameLabel matlab.ui.control.Label

        ImgSection          matlab.ui.container.Panel
        ImgButton           matlab.ui.control.Button
        ImgStatusLabel      matlab.ui.control.Label
        ImgFilenameLabel    matlab.ui.control.Label

        % --- W/L section ---
        WLSection           matlab.ui.container.Panel
        BrightnessSlider    matlab.ui.control.Slider
        BrightnessLabel     matlab.ui.control.Label
        ContrastSlider      matlab.ui.control.Slider
        ContrastLabel       matlab.ui.control.Label
        LowPctSlider        matlab.ui.control.Slider
        LowPctLabel         matlab.ui.control.Label
        HighPctSlider       matlab.ui.control.Slider
        HighPctLabel        matlab.ui.control.Label
        ApplyWLButton       matlab.ui.control.Button
        ResetWLButton       matlab.ui.control.Button

        % --- Kernel section ---
        KernelSection       matlab.ui.container.Panel
        TauRiseField        matlab.ui.control.NumericEditField
        TauDecayField       matlab.ui.control.NumericEditField

        % --- Render section ---
        RenderSection       matlab.ui.container.Panel
        DurSecField         matlab.ui.control.NumericEditField
        NFramesField        matlab.ui.control.NumericEditField
        SpeedField          matlab.ui.control.NumericEditField
        OutFilenameField    matlab.ui.control.EditField

        % --- Overlay style ---
        StyleSection        matlab.ui.container.Panel
        ColorModeSwitch     matlab.ui.control.Switch
        OverlayRSlider      matlab.ui.control.Slider
        OverlayGSlider      matlab.ui.control.Slider
        OverlayBSlider      matlab.ui.control.Slider
        AlphaMaxSlider      matlab.ui.control.Slider
        AlphaMaxLabel       matlab.ui.control.Label

        % --- Action buttons ---
        PreviewButton       matlab.ui.control.Button
        PreviewDurField     matlab.ui.control.NumericEditField
        RenderButton        matlab.ui.control.Button
        AdvancedButton      matlab.ui.control.Button

        % --- Right panel: axes + log ---
        PreviewAxes         matlab.ui.control.UIAxes
        LogTextArea         matlab.ui.control.TextArea
        StatusLabel         matlab.ui.control.Label
        ProgressBar         % we draw a custom axes-bar
        ProgressAxes        matlab.ui.control.UIAxes

        % ── Data ──────────────────────────────────────────────────────────
        ops             = []       % struct from Fall.mat
        iscellFlags     = []       % [N×2] from Fall.mat
        stat            = []       % cell/struct from Fall.mat
        path1_phys      = struct() % struct with spiketimes field
        MeanImRaw       = []       % double [Ly×Lx] raw mean image
        MeanImDisplay   = []       % after W/L
        cancelRequested logical = false
        fallLoaded      logical = false
        spikesLoaded    logical = false
        imgLoaded       logical = false
    end

    % ══════════════════════════════════════════════════════════════════════
    methods (Access = private)

        % ── Build UI ───────────────────────────────────────────────────────
        function buildUI(app)
            % Figure
            app.UIFigure = uifigure('Name','ROI Blink Overlay — Suite2p', ...
                'Position',[100 80 1180 760], ...
                'Color',[0.09 0.10 0.13], ...
                'Resize','on');

            % Main grid: left sidebar | right preview
            app.MainGrid = uigridlayout(app.UIFigure,[1 2]);
            app.MainGrid.ColumnWidth  = {340,'1x'};
            app.MainGrid.RowHeight    = {'1x'};
            app.MainGrid.BackgroundColor = [0.09 0.10 0.13];
            app.MainGrid.Padding = [0 0 0 0];

            % ── LEFT panel (scrollable) ────────────────────────────────────
            app.LeftPanel = uipanel(app.MainGrid);
            app.LeftPanel.Layout.Column = 1;
            app.LeftPanel.BackgroundColor = [0.07 0.08 0.11];
            app.LeftPanel.BorderType = 'none';

            % Scrollable inner grid
            app.LeftScroll = uigridlayout(app.LeftPanel, [99 1]);
            app.LeftScroll.RowHeight = repmat({32},1,99);  % filled in buildSections
            app.LeftScroll.ColumnWidth = {'1x'};
            app.LeftScroll.Padding = [10 10 10 10];
            app.LeftScroll.RowSpacing = 6;
            app.LeftScroll.BackgroundColor = [0.07 0.08 0.11];
            app.LeftScroll.Scrollable = 'on';

            % ── RIGHT panel ───────────────────────────────────────────────
            app.RightPanel = uipanel(app.MainGrid);
            app.RightPanel.Layout.Column = 2;
            app.RightPanel.BackgroundColor = [0.09 0.10 0.13];
            app.RightPanel.BorderType = 'none';

            rightGrid = uigridlayout(app.RightPanel,[3 1]);
            rightGrid.RowHeight = {'1x',60,28};
            rightGrid.ColumnWidth = {'1x'};
            rightGrid.Padding = [12 12 12 8];
            rightGrid.RowSpacing = 6;
            rightGrid.BackgroundColor = [0.09 0.10 0.13];

            % Preview axes
            app.PreviewAxes = uiaxes(rightGrid);
            app.PreviewAxes.Layout.Row = 1;
            app.PreviewAxes.Color = [0.06 0.07 0.09];
            app.PreviewAxes.XColor = [0.3 0.35 0.45];
            app.PreviewAxes.YColor = [0.3 0.35 0.45];
            app.PreviewAxes.XTick = [];
            app.PreviewAxes.YTick = [];
            title(app.PreviewAxes,'Mean projection preview','Color',[0.55 0.6 0.7],'FontSize',11);
            axis(app.PreviewAxes,'image');

            % Log text area
            app.LogTextArea = uitextarea(rightGrid);
            app.LogTextArea.Layout.Row = 2;
            app.LogTextArea.BackgroundColor = [0.05 0.06 0.08];
            app.LogTextArea.FontColor = [0.45 0.85 0.65];
            app.LogTextArea.FontName = 'Courier New';
            app.LogTextArea.FontSize = 10;
            app.LogTextArea.Editable = 'off';
            app.LogTextArea.Value = {'// output log'};

            % Status bar
            app.StatusLabel = uilabel(rightGrid);
            app.StatusLabel.Layout.Row = 3;
            app.StatusLabel.Text = '● Waiting for files';
            app.StatusLabel.FontColor = [0.4 0.45 0.55];
            app.StatusLabel.FontSize = 11;
            app.StatusLabel.FontName = 'Courier New';

            % ── Build all sidebar sections ─────────────────────────────────
            row = 1;
            row = app.buildFallSection(row);
            row = app.buildSpikesSection(row);
            row = app.buildImgSection(row);
            row = app.buildWLSection(row);
            row = app.buildKernelSection(row);
            row = app.buildRenderSection(row);
            row = app.buildStyleSection(row);
            app.buildActionButtons(row);

            % Fix actual row heights used
            app.LeftScroll.RowHeight(1:row+4) = ...
                num2cell(repmat(30, 1, row+4));
        end

        % ── SPIKES section ────────────────────────────────────────────────
        function row = buildSpikesSection(app, row)
            app.sectionLabel('SPIKETIMES  —  separate .mat file', row); row=row+1;

            app.SpikesButton = uibutton(app.LeftScroll,'push');
            app.SpikesButton.Layout.Row = row; row=row+1;
            app.SpikesButton.Text = '⚡  Load spiketimes .mat…';
            app.SpikesButton.ButtonPushedFcn = @(~,~) app.loadSpikes();
            app.styleButton(app.SpikesButton,'normal');

            app.SpikesFilenameLabel = app.infoLabel('no file loaded', row); row=row+1;
            app.SpikesStatusLabel   = app.infoLabel('expects path1_phys.spiketimes', row); row=row+1;
            app.divider(row); row=row+1;
        end

        % ── Load spiketimes .mat ──────────────────────────────────────────
        function loadSpikes(app)
            [f,p] = uigetfile({'*.mat','MAT files (*.mat)'},'Select spiketimes .mat');
            if isequal(f,0), return; end
            fullpath = fullfile(p,f);
            app.logMsg(sprintf('Loading spiketimes: %s …', f));
            drawnow;

            try
                data = load(fullpath);

                % ── Search strategy ───────────────────────────────────────
                % We walk up to 2 levels deep across every top-level variable
                % looking for a field named 'spiketimes' (or alias 'spks').
                % The first match wins.  Path is logged so user can verify.
                %
                % Examples that will all resolve:
                %   data.path1_phys.spiketimes          (level 2)
                %   data.path1.spiketimes               (level 2)
                %   data.myStruct.path1_phys.spiketimes (level 3 — caught by level-2 loop)
                %   data.spiketimes                     (level 1)
                %   data.spks                           (level 1)

                aliases   = {'spiketimes','spks','spike_times','spikeTimes','t_spikes'};
                foundVal  = [];
                foundPath = '';

                topVars = fieldnames(data);

                % Level 1: top-level fields of the loaded struct
                for i = 1:numel(topVars)
                    v = topVars{i};
                    for a = 1:numel(aliases)
                        if strcmp(v, aliases{a})
                            foundVal  = data.(v);
                            foundPath = v;
                            break;
                        end
                    end
                    if ~isempty(foundPath), break; end
                end

                % Level 2: one level inside each top-level struct variable
                if isempty(foundPath)
                    for i = 1:numel(topVars)
                        v = topVars{i};
                        s = data.(v);
                        if ~isstruct(s), continue; end
                        subFields = fieldnames(s);
                        for j = 1:numel(subFields)
                            sf = subFields{j};
                            for a = 1:numel(aliases)
                                if strcmp(sf, aliases{a})
                                    foundVal  = s.(sf);
                                    foundPath = sprintf('%s.%s', v, sf);
                                    break;
                                end
                            end
                            if ~isempty(foundPath), break; end
                        end
                        if ~isempty(foundPath), break; end
                    end
                end

                % Level 3: two levels inside (e.g. data.out.path1.spiketimes)
                if isempty(foundPath)
                    for i = 1:numel(topVars)
                        v = topVars{i};
                        s1 = data.(v);
                        if ~isstruct(s1), continue; end
                        mid = fieldnames(s1);
                        for m = 1:numel(mid)
                            s2 = s1.(mid{m});
                            if ~isstruct(s2), continue; end
                            subFields = fieldnames(s2);
                            for j = 1:numel(subFields)
                                sf = subFields{j};
                                for a = 1:numel(aliases)
                                    if strcmp(sf, aliases{a})
                                        foundVal  = s2.(sf);
                                        foundPath = sprintf('%s.%s.%s', v, mid{m}, sf);
                                        break;
                                    end
                                end
                                if ~isempty(foundPath), break; end
                            end
                            if ~isempty(foundPath), break; end
                        end
                        if ~isempty(foundPath), break; end
                    end
                end

                % ── Result ────────────────────────────────────────────────
                if isempty(foundPath)
                    % Nothing found — print the full 2-level tree to help user
                    msg = app.dumpStructTree(data, 2);
                    error('Could not find spiketimes (searched aliases: %s).\n\nFile contents:\n%s', ...
                        strjoin(aliases,', '), msg);
                end

                app.path1_phys.spiketimes = foundVal;
                nUnits = numel(foundVal);

                app.SpikesFilenameLabel.Text = f;
                app.SpikesStatusLabel.Text   = sprintf('✓  %d units  |  %s', nUnits, foundPath);
                app.SpikesStatusLabel.FontColor = [0.29 0.94 0.69];
                app.logMsg(sprintf('Found: %s  (%d units)', foundPath, nUnits),'ok');

                app.spikesLoaded = true;
                app.checkReady();

            catch ME
                app.logMsg(sprintf('ERROR: %s', ME.message),'err');
                uialert(app.UIFigure, ME.message,'Spiketimes load error','Icon','error');
            end
        end

        % ── Print a 2-level field tree for error diagnostics ──────────────
        function txt = dumpStructTree(~, s, maxDepth)
            lines = {};
            flds  = fieldnames(s);
            for i = 1:numel(flds)
                f  = flds{i};
                v  = s.(f);
                sz = mat2str(size(v));
                lines{end+1} = sprintf('  %s  [%s %s]', f, class(v), sz); %#ok<AGROW>
                if maxDepth > 1 && isstruct(v)
                    sub = fieldnames(v);
                    for j = 1:numel(sub)
                        sv  = v(1).(sub{j});
                        ssz = mat2str(size(sv));
                        lines{end+1} = sprintf('    .%s  [%s %s]', sub{j}, class(sv), ssz); %#ok<AGROW>
                    end
                end
            end
            txt = strjoin(lines, newline);
        end

        % ── FALL.MAT section ──────────────────────────────────────────────
        function row = buildFallSection(app, row)
            lbl = app.sectionLabel('FALL.MAT  —  ops · iscell · stat', row);
            lbl.Layout.Row = row; row=row+1;

            app.FallButton = uibutton(app.LeftScroll,'push');
            app.FallButton.Layout.Row = row; row=row+1;
            app.FallButton.Text = '📂  Load Fall.mat…';
            app.FallButton.ButtonPushedFcn = @(~,~) app.loadFall();
            app.styleButton(app.FallButton,'accent');

            app.FallFilenameLabel = app.infoLabel('no file loaded', row); row=row+1;
            app.FallStatusLabel   = app.infoLabel('', row); row=row+1;

            fpsRow = uigridlayout(app.LeftScroll,[1 2]);
            fpsRow.Layout.Row = row; row=row+1;
            fpsRow.ColumnWidth = {'fit','1x'};
            fpsRow.Padding=[0 0 0 0]; fpsRow.RowSpacing=0;
            fpsRow.BackgroundColor=[0.07 0.08 0.11];
            lf = uilabel(fpsRow,'Text','ops.fs →','FontColor',[0.4 0.45 0.55],...
                'FontName','Courier New','FontSize',10);
            lf.Layout.Column=1;
            app.FPSValueLabel = uilabel(fpsRow,'Text','—  Hz', ...
                'FontColor',[0.29 0.94 0.69],'FontName','Courier New','FontSize',10,...
                'FontWeight','bold');
            app.FPSValueLabel.Layout.Column=2;
            app.divider(row); row=row+1;
        end

        % ── Mean image section ────────────────────────────────────────────
        function row = buildImgSection(app, row)
            app.sectionLabel('MEAN IMAGE  —  override (optional)', row);
            row=row+1;

            app.ImgButton = uibutton(app.LeftScroll,'push');
            app.ImgButton.Layout.Row = row; row=row+1;
            app.ImgButton.Text = '🖼  Load image / mat override…';
            app.ImgButton.ButtonPushedFcn = @(~,~) app.loadMeanImage();
            app.styleButton(app.ImgButton,'normal');

            app.ImgFilenameLabel = app.infoLabel('jpg · tif · png · mat (ops.meanImg)',row); row=row+1;
            app.ImgStatusLabel   = app.infoLabel('using ops.meanImg from Fall.mat',row);    row=row+1;
            app.divider(row); row=row+1;
        end

        % ── W/L section ───────────────────────────────────────────────────
        function row = buildWLSection(app, row)
            app.sectionLabel('WINDOW / LEVEL  &  CONTRAST', row); row=row+1;

            [app.BrightnessSlider, app.BrightnessLabel, row] = ...
                app.sliderRow('Brightness', -100, 100, 0, row);
            [app.ContrastSlider,   app.ContrastLabel,   row] = ...
                app.sliderRow('Contrast ×', 0.1, 4, 1, row);
            [app.LowPctSlider,     app.LowPctLabel,     row] = ...
                app.sliderRow('Low pct clip', 0, 20, 1, row);
            [app.HighPctSlider,    app.HighPctLabel,     row] = ...
                app.sliderRow('High pct clip', 80, 100, 99.9, row);

            btnG = uigridlayout(app.LeftScroll,[1 2]);
            btnG.Layout.Row=row; row=row+1;
            btnG.ColumnWidth={'1x','1x'};
            btnG.Padding=[0 0 0 0]; btnG.BackgroundColor=[0.07 0.08 0.11];

            app.ApplyWLButton = uibutton(btnG,'push');
            app.ApplyWLButton.Layout.Column=1;
            app.ApplyWLButton.Text = '↺  Apply W/L';
            app.ApplyWLButton.ButtonPushedFcn = @(~,~) app.applyWL();
            app.styleButton(app.ApplyWLButton,'normal');

            app.ResetWLButton = uibutton(btnG,'push');
            app.ResetWLButton.Layout.Column=2;
            app.ResetWLButton.Text = 'Reset';
            app.ResetWLButton.ButtonPushedFcn = @(~,~) app.resetWL();
            app.styleButton(app.ResetWLButton,'normal');

            app.divider(row); row=row+1;
        end

        % ── Kernel section ────────────────────────────────────────────────
        function row = buildKernelSection(app, row)
            app.sectionLabel('CALCIUM KERNEL', row); row=row+1;

            % Labels row
            lblG = uigridlayout(app.LeftScroll,[1 2]);
            lblG.Layout.Row=row; row=row+1;
            lblG.ColumnWidth={'1x','1x'}; lblG.RowHeight={'1x'};
            lblG.Padding=[0 0 0 0]; lblG.BackgroundColor=[0.07 0.08 0.11];
            app.labelInGrid(lblG,'τ rise (s)',1,1);
            app.labelInGrid(lblG,'τ decay (s)',1,2);

            % Fields row
            fldG = uigridlayout(app.LeftScroll,[1 2]);
            fldG.Layout.Row=row; row=row+1;
            fldG.ColumnWidth={'1x','1x'}; fldG.RowHeight={'1x'};
            fldG.Padding=[0 0 0 0]; fldG.BackgroundColor=[0.07 0.08 0.11];
            app.TauRiseField  = app.numField(fldG, 0.07, 0.001, 5,  1, 1);
            app.TauDecayField = app.numField(fldG, 0.7,  0.01,  20, 1, 2);

            app.divider(row); row=row+1;
        end

        % ── Render section ────────────────────────────────────────────────
        function row = buildRenderSection(app, row)
            app.sectionLabel('RENDER PARAMETERS', row); row=row+1;

            % Duration + NFrames labels
            durLblG = uigridlayout(app.LeftScroll,[1 2]);
            durLblG.Layout.Row=row; row=row+1;
            durLblG.ColumnWidth={'1x','1x'}; durLblG.RowHeight={'1x'};
            durLblG.Padding=[0 0 0 0]; durLblG.BackgroundColor=[0.07 0.08 0.11];
            app.labelInGrid(durLblG,'Duration (s)  [0 = auto]',1,1);
            app.labelInGrid(durLblG,'N frames  [0 = auto]',1,2);

            % Duration + NFrames fields
            durFldG = uigridlayout(app.LeftScroll,[1 2]);
            durFldG.Layout.Row=row; row=row+1;
            durFldG.ColumnWidth={'1x','1x'}; durFldG.RowHeight={'1x'};
            durFldG.Padding=[0 0 0 0]; durFldG.BackgroundColor=[0.07 0.08 0.11];
            app.DurSecField  = app.numField(durFldG, 0, 0, 1e6, 1, 1);
            app.NFramesField = app.numField(durFldG, 0, 0, 1e6, 1, 2);

            % Speed label
            app.sectionLabel('Playback speed (× native fps)  — default 2×', row); row=row+1;

            % Speed field
            spdG = uigridlayout(app.LeftScroll,[1 1]);
            spdG.Layout.Row=row; row=row+1;
            spdG.ColumnWidth={'1x'}; spdG.RowHeight={'1x'};
            spdG.Padding=[0 0 0 0]; spdG.BackgroundColor=[0.07 0.08 0.11];
            app.SpeedField = app.numField(spdG, 2, 0.25, 20, 1, 1);

            % Filename label
            app.sectionLabel('Output filename (.mp4)', row); row=row+1;

            % Filename field
            app.OutFilenameField = uieditfield(app.LeftScroll, 'text');
            app.OutFilenameField.Layout.Row=row; row=row+1;
            app.OutFilenameField.Value = '';
            app.OutFilenameField.Placeholder = 'roi_blink_overlay.mp4';
            app.styleEditField(app.OutFilenameField);

            app.divider(row); row=row+1;
        end

        % ── Style section ─────────────────────────────────────────────────
        function row = buildStyleSection(app, row)
            app.sectionLabel('OVERLAY STYLE', row); row=row+1;

            % Color mode label + switch on separate rows
            app.sectionLabel('Color mode', row); row=row+1;
            app.ColorModeSwitch = uiswitch(app.LeftScroll,'slider');
            app.ColorModeSwitch.Layout.Row = row; row=row+1;
            app.ColorModeSwitch.Items     = {'Single color','Unique per ROI'};
            app.ColorModeSwitch.Value     = 'Single color';
            app.ColorModeSwitch.FontColor = [0.55 0.6 0.7];
            app.ColorModeSwitch.FontSize  = 10;

            % RGB sliders for overlay color
            [app.OverlayRSlider,~,row] = app.sliderRow('Red   (R)', 0, 1, 1, row);
            [app.OverlayGSlider,~,row] = app.sliderRow('Green (G)', 0, 1, 1, row);
            [app.OverlayBSlider,~,row] = app.sliderRow('Blue  (B)', 0, 1, 1, row);

            [app.AlphaMaxSlider, app.AlphaMaxLabel, row] = ...
                app.sliderRow('Alpha max', 0.1, 1, 0.85, row);
            app.divider(row); row=row+1;
        end

        % ── Action buttons ────────────────────────────────────────────────
        function buildActionButtons(app, row)
            % Row 1: Preview duration label
            app.sectionLabel('Preview duration (s)', row); row=row+1;

            % Row 2: Preview dur field + Preview button + Advanced button
            topG = uigridlayout(app.LeftScroll,[1 3]);
            topG.Layout.Row = row; row = row+1;  %#ok<NASGU>
            topG.ColumnWidth = {50,'1x','1x'}; topG.RowHeight = {'1x'};
            topG.Padding = [0 4 0 4]; topG.BackgroundColor = [0.07 0.08 0.11];

            % Editable duration field (seconds)
            app.PreviewDurField = uieditfield(topG,'numeric');
            app.PreviewDurField.Layout.Row=1; app.PreviewDurField.Layout.Column=1;
            app.PreviewDurField.Value = 5;
            app.PreviewDurField.Limits = [1 3600];
            app.PreviewDurField.FontColor = [0.85 0.88 0.95];
            app.PreviewDurField.BackgroundColor = [0.11 0.13 0.18];
            app.PreviewDurField.FontName = 'Courier New';
            app.PreviewDurField.FontSize = 11;

            app.PreviewButton = uibutton(topG,'push');
            app.PreviewButton.Layout.Row=1; app.PreviewButton.Layout.Column=2;
            app.PreviewButton.Text = '▶  Preview';
            app.PreviewButton.ButtonPushedFcn = @(~,~) app.runPreview();
            app.PreviewButton.Enable = 'off';
            app.styleButton(app.PreviewButton,'secondary');

            app.AdvancedButton = uibutton(topG,'push');
            app.AdvancedButton.Layout.Row=1; app.AdvancedButton.Layout.Column=3;
            app.AdvancedButton.Text = '⚙  Advanced';
            app.AdvancedButton.ButtonPushedFcn = @(~,~) app.openAdvanced();
            app.styleButton(app.AdvancedButton,'normal');

            % Row 3: Generate MP4 full-width
            app.RenderButton = uibutton(app.LeftScroll,'push');
            app.RenderButton.Layout.Row = row;
            app.RenderButton.Text = '⬛  Generate MP4';
            app.RenderButton.ButtonPushedFcn = @(~,~) app.runRender();
            app.RenderButton.Enable = 'off';
            app.styleButton(app.RenderButton,'accent');
        end

        % ══════════════════════════════════════════════════════════════════
        % ── File loading callbacks ─────────────────────────────────────────

        function loadFall(app)
            [f,p] = uigetfile({'Fall.mat;*.mat','MAT files (*.mat)'},'Select Fall.mat');
            if isequal(f,0), return; end
            fullpath = fullfile(p,f);
            app.logMsg(sprintf('Loading %s …', f));
            drawnow;

            try
                data = load(fullpath);

                % ops
                if ~isfield(data,'ops')
                    error('Fall.mat does not contain ''ops'' struct.');
                end
                app.ops = data.ops;

                % iscell
                if isfield(data,'iscell')
                    app.iscellFlags = data.iscell;
                elseif isfield(data,'is_cell')
                    app.iscellFlags = data.is_cell;
                else
                    error('Could not find iscell in Fall.mat.');
                end

                % stat
                if isfield(data,'stat')
                    app.stat = data.stat;
                else
                    error('Could not find stat in Fall.mat.');
                end

                % FPS from ops.fs
                fps = 22.93; % default
                if isfield(app.ops,'fs')
                    fps = app.ops.fs;
                elseif isfield(app.ops,'fshz')
                    fps = app.ops.fshz;
                end
                app.FPSValueLabel.Text = sprintf('%.3f  Hz', fps);

                % Load mean image from ops.meanImg if no override yet
                if ~app.imgLoaded
                    if isfield(app.ops,'meanImg') && ~isempty(app.ops.meanImg)
                        app.MeanImRaw = im2double(app.ops.meanImg);
                        app.MeanImDisplay = app.MeanImRaw;
                        app.refreshPreview();
                        app.ImgStatusLabel.Text = 'using ops.meanImg from Fall.mat';
                    else
                        app.logMsg('ops.meanImg not found — load a separate image.','warn');
                    end
                end

                % UI feedback
                nCell = sum(app.iscellFlags(:,1)==1);
                app.FallFilenameLabel.Text = f;
                app.FallStatusLabel.Text = sprintf('✓  %d ROIs (iscell==1)  |  fps=%.2f', nCell, fps);
                app.FallStatusLabel.FontColor = [0.29 0.94 0.69];
                app.logMsg(sprintf('Loaded: %s', f),'ok');
                app.logMsg(sprintf('%d total ROIs, %d iscell==1, fps=%.3f', ...
                    size(app.iscellFlags,1), nCell, fps));

                app.fallLoaded = true;
                app.checkReady();

            catch ME
                app.logMsg(sprintf('ERROR: %s', ME.message),'err');
                uialert(app.UIFigure, ME.message, 'Load error','Icon','error');
            end
        end

        function loadMeanImage(app)
            [f,p] = uigetfile( ...
                {'*.jpg;*.jpeg;*.png;*.tif;*.tiff;*.mat', ...
                 'Image / MAT files'}, 'Select mean image');
            if isequal(f,0), return; end
            fullpath = fullfile(p,f);
            ext = lower(f(find(f=='.',1,'last')+1:end));

            try
                if strcmp(ext,'mat')
                    d = load(fullpath,'ops');
                    if ~isfield(d,'ops') || ~isfield(d.ops,'meanImg')
                        error('MAT file has no ops.meanImg field.');
                    end
                    raw = im2double(d.ops.meanImg);
                else
                    raw = im2double(imread(fullpath));
                    if size(raw,3)==3, raw = rgb2gray(raw); end
                end
                app.MeanImRaw     = raw;
                app.MeanImDisplay = raw;
                app.refreshPreview();
                app.ImgFilenameLabel.Text = f;
                app.ImgStatusLabel.Text   = sprintf('override: %d×%d px', size(raw,2), size(raw,1));
                app.ImgStatusLabel.FontColor = [0.29 0.94 0.69];
                app.imgLoaded = true;
                app.logMsg(sprintf('Mean image override: %s  (%d×%d)', f, size(raw,2), size(raw,1)),'ok');
                app.checkReady();
            catch ME
                app.logMsg(sprintf('ERROR loading image: %s', ME.message),'err');
                uialert(app.UIFigure, ME.message,'Image load error','Icon','error');
            end
        end

        % ── Preview / W/L ─────────────────────────────────────────────────

        function refreshPreview(app)
            if isempty(app.MeanImDisplay), return; end
            imshow(app.MeanImDisplay, [], 'Parent', app.PreviewAxes);
            axis(app.PreviewAxes,'image');
            app.PreviewAxes.XTick=[]; app.PreviewAxes.YTick=[];
            drawnow;
        end

        function applyWL(app)
            if isempty(app.MeanImRaw), return; end
            lo  = app.LowPctSlider.Value;
            hi  = app.HighPctSlider.Value;
            b   = app.BrightnessSlider.Value / 100;
            c   = app.ContrastSlider.Value;

            im = app.MeanImRaw;
            pLo = prctile(im(:), lo);
            pHi = prctile(im(:), hi);
            im  = (im - pLo) / max(pHi - pLo, eps);
            im  = im * c + b;
            im  = min(max(im,0),1);
            app.MeanImDisplay = im;
            app.refreshPreview();
            app.logMsg(sprintf('W/L applied: bright=%.2f  contrast=%.2f×  lo=%.1f%%  hi=%.1f%%', ...
                b, c, lo, hi));
        end

        function resetWL(app)
            app.BrightnessSlider.Value = 0;
            app.ContrastSlider.Value   = 1;
            app.LowPctSlider.Value     = 1;
            app.HighPctSlider.Value    = 99.9;
            app.BrightnessLabel.Text   = '0';
            app.ContrastLabel.Text     = '1.00';
            app.LowPctLabel.Text       = '1.0';
            app.HighPctLabel.Text      = '99.9';
            if ~isempty(app.MeanImRaw)
                app.MeanImDisplay = app.MeanImRaw;
                app.refreshPreview();
            end
            app.logMsg('W/L reset to defaults.');
        end

        % ── Readiness check ────────────────────────────────────────────────
        function checkReady(app)
            ready = app.fallLoaded && app.spikesLoaded;
            if ready
                app.PreviewButton.Enable = 'on';
                app.RenderButton.Enable  = 'on';
                app.StatusLabel.Text     = '● Ready to render';
                app.StatusLabel.FontColor = [0.29 0.94 0.69];
                app.logMsg('Pipeline ready — Fall.mat + spiketimes loaded.','ok');
            elseif app.fallLoaded
                app.StatusLabel.Text = '● Waiting for spiketimes file';
                app.StatusLabel.FontColor = [0.95 0.65 0.25];
            elseif app.spikesLoaded
                app.StatusLabel.Text = '● Waiting for Fall.mat';
                app.StatusLabel.FontColor = [0.95 0.65 0.25];
            end
        end

        % ── Preview ───────────────────────────────────────────────────────
        function runPreview(app)
            prevDur = app.PreviewDurField.Value;
            app.logMsg(sprintf('Generating %.0f-second preview…', prevDur));
            app.StatusLabel.Text = '● Generating preview…';
            app.StatusLabel.FontColor = [0.95 0.65 0.25];
            drawnow;
            try
                opts = app.gatherOptions();
                opts.DurationSec = prevDur;
                opts.NFrames     = [];
                [~,base,~] = fileparts(opts.Output);
                if isempty(base), base = 'roi_blink_overlay'; end
                opts.Output = [base sprintf('_preview%.0fs.mp4', prevDur)];
                app.callCoreWithProgress(opts, ...
                    sprintf('Preview (%.0f s)', prevDur));
            catch ME
                if ~strcmp(ME.identifier,'ROIApp:Cancelled')
                    app.logMsg(sprintf('Preview error: %s', ME.message),'err');
                    app.StatusLabel.Text = '● Error';
                    app.StatusLabel.FontColor = [0.95 0.35 0.35];
                end
            end
        end

        % ── Full render ───────────────────────────────────────────────────
        function runRender(app)
            opts = app.gatherOptions();
            app.logMsg(sprintf('Rendering → %s', opts.Output));
            app.logMsg(sprintf('τ_rise=%.3f s  τ_decay=%.2f s', ...
                opts.Params.tau_rise, opts.Params.tau_decay));
            app.StatusLabel.Text = '● Rendering…';
            app.StatusLabel.FontColor = [0.95 0.65 0.25];
            drawnow;
            try
                app.callCoreWithProgress(opts, 'Full render');
            catch ME
                if ~strcmp(ME.identifier,'ROIApp:Cancelled')
                    app.logMsg(sprintf('Render error: %s', ME.message),'err');
                    app.StatusLabel.Text = '● Error';
                    app.StatusLabel.FontColor = [0.95 0.35 0.35];
                end
            end
        end

        % ── Gather options struct from UI ──────────────────────────────────
        function opts = gatherOptions(app)
            fpsParts = strsplit(app.FPSValueLabel.Text, 'Hz');
            fps = str2double(strtrim(fpsParts{1}));
            if isnan(fps), fps = 22.93; end

            speed = app.SpeedField.Value;
            if isnan(speed)||speed<=0, speed=2; end

            params.tau_rise  = app.TauRiseField.Value;
            params.tau_decay = app.TauDecayField.Value;

            outFile = strtrim(app.OutFilenameField.Value);
            if isempty(outFile), outFile = 'roi_blink_overlay.mp4'; end
            if ~endsWith(outFile,'.mp4'), outFile = [outFile '.mp4']; end

            colorByROI = strcmp(app.ColorModeSwitch.Value,'Unique per ROI');
            R = app.OverlayRSlider.Value;
            G = app.OverlayGSlider.Value;
            B = app.OverlayBSlider.Value;

            opts.Params        = params;
            opts.FPS           = fps * speed;
            opts.FPS_native    = fps;
            opts.PlaybackSpeed = speed;
            opts.Quality       = 95;             % from Advanced, default
            opts.DurationSec   = app.zeroOrVal(app.DurSecField.Value);
            opts.NFrames       = app.zeroOrVal(app.NFramesField.Value);
            opts.Output        = outFile;
            opts.BaseContrast  = [app.LowPctSlider.Value, app.HighPctSlider.Value];
            opts.ClipPercent   = 99;
            opts.GlobalScale   = true;
            opts.OverlayColor  = [R G B];
            opts.ColorByROI    = colorByROI;
            opts.AlphaMax      = app.AlphaMaxSlider.Value;
        end

        function v = zeroOrVal(~, x)
            % 0 means "auto" (user left field at default)
            if x == 0, v = []; else, v = x; end
        end

        % ── Call the core rendering function ──────────────────────────────
        function callCore(app, opts)
            % Reconstruct ops with potentially W/L-adjusted mean image
            opsLocal = app.ops;
            if ~isempty(app.MeanImDisplay)
                opsLocal.meanImg = app.MeanImDisplay;
            end

            % Build the varargin key-value list for the original function
            vargs = { ...
                'Params',       opts.Params, ...
                'FPS',          opts.FPS_native, ...
                'Output',       opts.Output, ...
                'BaseContrast', opts.BaseContrast, ...
                'ClipPercent',  opts.ClipPercent, ...
                'GlobalScale',  opts.GlobalScale, ...
                'OverlayColor', opts.OverlayColor, ...
                'ColorByROI',   opts.ColorByROI, ...
                'AlphaMax',     opts.AlphaMax ...
            };
            if ~isempty(opts.DurationSec)
                vargs = [vargs, {'DurationSec', opts.DurationSec}];
            end
            if ~isempty(opts.NFrames)
                vargs = [vargs, {'NFrames', opts.NFrames}];
            end

            % Call the original function (must be on MATLAB path)
            overlayBlinkingROIs_onMean(opsLocal, app.path1_phys, ...
                app.stat, app.iscellFlags, vargs{:});
        end

        % ── Progress-aware render — re-implements the frame loop so we can
        %    update the dialog every frame and support Cancel. ───────────────
        function callCoreWithProgress(app, opts, jobLabel)

            % ── Progress dialog ──────────────────────────────────────────
            dlg = uiprogressdlg(app.UIFigure, ...
                'Title',   jobLabel, ...
                'Message', 'Preparing…', ...
                'Value',   0, ...
                'Cancelable', 'on');
            app.cancelRequested = false;
            cleanupDlg = onCleanup(@() delete(dlg));

            try
                % ── Re-run the setup steps from the core function ────────
                dlg.Message = 'Parsing parameters…'; drawnow;

                params     = opts.Params;
                tau_rise   = params.tau_rise;
                tau_decay  = params.tau_decay;
                fps_native = opts.FPS_native;
                dt         = 1 / fps_native;

                % Select iscell==1 ROIs
                roiIsCell = find(app.iscellFlags(:,1)==1);
                nKeep     = numel(roiIsCell);

                % Spike bag
                spkBag      = app.path1_phys.spiketimes;
                isSpkCell   = iscell(spkBag);
                isSpkStruct = isstruct(spkBag);

                % Image size from stat
                dlg.Message = 'Reading ROI pixels…'; drawnow;
                [Ly, Lx, zeroBased] = local_infer_image_size(app.stat, app.iscellFlags);

                % Build pixel index masks
                maskIdx = cell(nKeep,1);
                for k = 1:nKeep
                    roi = roiIsCell(k);
                    S   = local_stat_at(app.stat, roi);
                    y = S.ypix(:); x = S.xpix(:);
                    if zeroBased, y=y+1; x=x+1; end
                    y = max(1,min(Ly,round(y)));
                    x = max(1,min(Lx,round(x)));
                    maskIdx{k} = sub2ind([Ly Lx], y, x);
                end

                % Mean image
                dlg.Message = 'Processing mean image…'; drawnow;
                if ~isempty(app.MeanImDisplay)
                    meanIm = im2double(imresize(app.MeanImDisplay,[Ly Lx]));
                else
                    meanIm = im2double(imresize(app.ops.meanImg,[Ly Lx]));
                end
                lo     = prctile(meanIm(:), opts.BaseContrast(1));
                hi     = prctile(meanIm(:), opts.BaseContrast(2));
                baseIm = (meanIm - lo) / max(hi-lo, eps);
                baseIm = min(max(baseIm,0),1);

                % Frame count
                if ~isempty(opts.NFrames)
                    nFrames = opts.NFrames;
                elseif ~isempty(opts.DurationSec)
                    nFrames = max(1, round(opts.DurationSec * fps_native));
                else
                    lastSpike = 0;
                    for k = 1:nKeep
                        st = local_get_spikes(spkBag,k,isSpkCell,isSpkStruct);
                        if ~isempty(st), lastSpike = max(lastSpike,max(st)); end
                    end
                    Tsec    = lastSpike + 5*max(tau_decay,tau_rise);
                    if ~isfinite(Tsec)||Tsec<=0, Tsec=10; end
                    nFrames = max(1, round(Tsec * fps_native));
                end
                t_edges = 0:dt:(nFrames*dt);

                % GECI kernel
                tmax = 5*max(tau_decay,tau_rise);
                kt   = 0:dt:tmax;
                kern = exp(-kt./tau_decay) - exp(-kt./tau_rise);
                kern = max(kern,0);
                if max(kern)>0, kern=kern./max(kern); end

                % Convolve spikes → Ca traces
                dlg.Message = 'Convolving spikes…'; drawnow;
                traces    = zeros(nKeep, nFrames,'single');
                globalMax = 0;
                for k = 1:nKeep
                    st = local_get_spikes(spkBag,k,isSpkCell,isSpkStruct);
                    if isempty(st), continue; end
                    bc          = histcounts(st, t_edges);
                    cs          = conv(single(bc), single(kern),'same');
                    traces(k,:) = cs;
                    if opts.GlobalScale, globalMax = max(globalMax,max(cs)); end
                end
                if opts.GlobalScale
                    traces = traces / max(eps, globalMax);
                else
                    for k=1:nKeep
                        m=max(traces(k,:)); if m>0, traces(k,:)=traces(k,:)/m; end
                    end
                end
                traces = min(max(traces,0),1);
                if opts.ClipPercent < 100
                    v = traces(:); v=v(v>0);
                    if ~isempty(v)
                        vm = prctile(v, opts.ClipPercent);
                        if isfinite(vm)&&vm>0, traces=min(traces/vm,1); end
                    end
                end

                % Color map
                if opts.ColorByROI
                    cmap = single(hsv(nKeep));
                else
                    cmap = single(repmat(opts.OverlayColor(:).', nKeep, 1));
                end

                % ── Pre-flatten base image for fast per-frame blending ────
                % baseFlat: [Ly*Lx × 3] single — stays constant every frame
                baseFlat = single(reshape(repmat(baseIm,[1 1 3]), Ly*Lx, 3));

                % Pre-build per-ROI pixel lists as a concatenated index +
                % ROI-ID vector so we can scatter-accumulate in one pass.
                % roiOf(i) = which ROI owns pixel i in allIdx
                allIdx  = vertcat(maskIdx{:});              % [totalPx × 1]
                roiOf   = zeros(numel(allIdx),1,'uint16');
                pos = 1;
                for k = 1:nKeep
                    n = numel(maskIdx{k});
                    roiOf(pos:pos+n-1) = k;
                    pos = pos + n;
                end
                nPx = numel(allIdx);

                % Pre-allocate frame batch buffer (write every batchSize frames)
                batchSize  = min(30, nFrames);
                frameBatch = zeros(Ly, Lx, 3, batchSize, 'uint8');
                batchCount = 0;

                % Video writer
                fps_out = opts.FPS_native * opts.PlaybackSpeed;
                vw = VideoWriter(opts.Output,'MPEG-4');
                vw.FrameRate = fps_out;
                vw.Quality   = opts.Quality;
                open(vw);
                app.logMsg(sprintf('Writing %s  —  %d frames @ %.1f fps', ...
                    opts.Output, nFrames, fps_out));

                % ── Frame loop ────────────────────────────────────────────
                alphaMax  = single(opts.AlphaMax);
                updateEvery = max(1, round(nFrames/200));

                for f = 1:nFrames

                    % Cancel check
                    if dlg.CancelRequested
                        close(vw);
                        delete(dlg);
                        app.logMsg('Cancelled by user.','warn');
                        app.StatusLabel.Text = '● Cancelled';
                        app.StatusLabel.FontColor = [0.95 0.65 0.25];
                        throw(MException('ROIApp:Cancelled','User cancelled.'));
                    end

                    % Progress update
                    if mod(f, updateEvery)==0 || f==nFrames
                        dlg.Value   = f / nFrames;
                        dlg.Message = sprintf('Frame %d / %d  (%.0f%%)', ...
                            f, nFrames, 100*f/nFrames);
                        drawnow limitrate;
                    end

                    % ── Vectorised alpha-blend ────────────────────────────
                    % alphas(k): scalar alpha for each ROI this frame
                    alphas = min(single(1), alphaMax .* traces(:,f));  % [nKeep × 1]

                    % Per-pixel alpha and color via lookup from roiOf
                    pxAlpha = alphas(roiOf);           % [nPx × 1]
                    pxColor = cmap(roiOf, :);          % [nPx × 3]

                    % Copy base, scatter-blend only pixels with nonzero alpha
                    frameFlat = baseFlat;              % [Ly*Lx × 3]
                    active = pxAlpha > 0;
                    if any(active)
                        ai  = allIdx(active);
                        aa  = pxAlpha(active);         % [m × 1]
                        ac  = pxColor(active, :);      % [m × 3]
                        % blend: dst = (1-a)*src + a*color
                        frameFlat(ai,:) = bsxfun(@times, 1-aa, frameFlat(ai,:)) ...
                                        + bsxfun(@times,   aa, ac);
                    end

                    % Reshape back to [Ly × Lx × 3] uint8
                    batchCount = batchCount + 1;
                    frameBatch(:,:,:,batchCount) = reshape( ...
                        uint8(frameFlat * 255), Ly, Lx, 3);

                    % Flush batch to disk
                    if batchCount == batchSize || f == nFrames
                        writeVideo(vw, frameBatch(:,:,:,1:batchCount));
                        batchCount = 0;
                    end
                end

                close(vw);
                app.logMsg(sprintf('Done → %s', opts.Output),'ok');
                app.StatusLabel.Text  = '● Complete';
                app.StatusLabel.FontColor = [0.29 0.94 0.69];
                app.RenderButton.Text = '✓  MP4 Ready';
                pause(2);
                app.RenderButton.Text = '⬛  Generate MP4';

            catch ME
                % Make sure video writer is closed on any error
                if exist('vw','var') && isvalid(vw) && strcmp(vw.Open,'true') %#ok<BDSCA>
                    try, close(vw); catch, end
                end
                rethrow(ME);
            end
        end

        % ── Advanced dialog ───────────────────────────────────────────────
        function openAdvanced(app)
            d = uifigure('Name','Advanced Parameters','Position',[300 250 460 380], ...
                'Color',[0.07 0.08 0.11],'Resize','off');

            g = uigridlayout(d,[15 2]);
            g.ColumnWidth={'1x','1x'};
            g.Padding=[16 16 16 16]; g.RowSpacing=6;
            g.BackgroundColor=[0.07 0.08 0.11];
            g.RowHeight = num2cell(repmat(26,1,15));

            function lbl = al(txt,r,c)
                lbl=uilabel(g,'Text',txt,'FontColor',[0.55 0.6 0.7],'FontSize',10);
                lbl.Layout.Row=r; lbl.Layout.Column=c;
            end
            function ef = anf(val,lo,hi,r,c)
                ef=uieditfield(g,'numeric','Value',val,'Limits',[lo hi], ...
                    'FontColor',[0.9 0.93 0.97],'BackgroundColor',[0.12 0.14 0.19], ...
                    'FontName','Courier New','FontSize',11);
                ef.Layout.Row=r; ef.Layout.Column=c;
            end

            al('── Base contrast ──────────',1,[1 2]);
            al('BaseContrast low %',2,1);   loF=anf(app.LowPctSlider.Value,0,50,2,2);
            al('BaseContrast high %',3,1);  hiF=anf(app.HighPctSlider.Value,50,100,3,2);

            al('── Trace normalisation ────',4,[1 2]);
            al('ClipPercent',5,1);   cpF=anf(99,1,100,5,2);
            al('GlobalScale (1=true)',6,1);
            gsDD=uidropdown(g,'Items',{'true','false'},'Value','true', ...
                'BackgroundColor',[0.12 0.14 0.19],'FontColor',[0.9 0.93 0.97],'FontSize',11);
            gsDD.Layout.Row=6; gsDD.Layout.Column=2;

            al('── Encoder ────────────────',7,[1 2]);
            al('Quality (1–100)',8,1);   qF=anf(95,1,100,8,2);
            al('Profile',9,1);
            profDD=uidropdown(g,'Items',{'MPEG-4','Uncompressed AVI','Motion JPEG AVI'}, ...
                'Value','MPEG-4','BackgroundColor',[0.12 0.14 0.19], ...
                'FontColor',[0.9 0.93 0.97],'FontSize',11);
            profDD.Layout.Row=9; profDD.Layout.Column=2;

            al('── Video duration (auto mode) ─',10,[1 2]);
            % Plain-English explanation label spanning both columns
            helpLbl = uilabel(g, 'Text', ...
                'When Duration=0 the video ends this many time-constants after the last spike.', ...
                'FontColor',[0.45 0.5 0.62],'FontSize',9,'WordWrap','on');
            helpLbl.Layout.Row=11; helpLbl.Layout.Column=[1 2];
            al('Extra seconds after last spike',12,1);  tmF=anf(5,1,20,12,2);

            saveBtn=uibutton(g,'push','Text','Save & Close', ...
                'BackgroundColor',[0.29 0.94 0.69],'FontColor',[0 0 0],'FontWeight','bold');
            saveBtn.Layout.Row=14; saveBtn.Layout.Column=[1 2];
            saveBtn.ButtonPushedFcn = @(~,~) advSave();

            cancelBtn=uibutton(g,'push','Text','Cancel', ...
                'BackgroundColor',[0.12 0.14 0.19],'FontColor',[0.6 0.65 0.75]);
            cancelBtn.Layout.Row=15; cancelBtn.Layout.Column=[1 2];
            cancelBtn.ButtonPushedFcn = @(~,~) close(d);

            function advSave()
                % Apply back to sliders where applicable
                app.LowPctSlider.Value  = loF.Value;
                app.HighPctSlider.Value = hiF.Value;
                app.LowPctLabel.Text    = sprintf('%.1f',loF.Value);
                app.HighPctLabel.Text   = sprintf('%.1f',hiF.Value);
                app.logMsg(sprintf('Advanced saved: clip=%d%%  global=%s  quality=%d  profile=%s  tail=%dx', ...
                    round(cpF.Value), gsDD.Value, round(qF.Value), profDD.Value, round(tmF.Value)),'ok');
                close(d);
            end
        end

        % ══════════════════════════════════════════════════════════════════
        % ── Logging helper ─────────────────────────────────────────────────
        function logMsg(app, msg, type)
            if nargin<3, type=''; end
            ts  = datestr(now,'HH:MM:SS');
            line = sprintf('[%s] %s', ts, msg);
            cur = app.LogTextArea.Value;
            if ischar(cur), cur = {cur}; end
            app.LogTextArea.Value = [cur; {line}];
            % scroll to bottom
            scroll(app.LogTextArea,'bottom');
            drawnow limitrate;
        end

        % ══════════════════════════════════════════════════════════════════
        % ── Styling helpers ────────────────────────────────────────────────
        function styleButton(~, btn, style)
            switch style
                case 'accent'
                    btn.BackgroundColor = [0.18 0.58 0.42];
                    btn.FontColor       = [0.9 1.0 0.95];
                    btn.FontWeight      = 'bold';
                case 'secondary'
                    btn.BackgroundColor = [0.10 0.18 0.30];
                    btn.FontColor       = [0.5 0.7 1.0];
                otherwise
                    btn.BackgroundColor = [0.14 0.16 0.22];
                    btn.FontColor       = [0.7 0.75 0.85];
            end
            btn.FontSize = 11;
        end

        function styleEditField(~, ef)
            ef.BackgroundColor = [0.11 0.13 0.18];
            ef.FontColor       = [0.85 0.88 0.95];
            ef.FontName        = 'Courier New';
            ef.FontSize        = 11;
        end

        function lbl = sectionLabel(app, txt, row)
            lbl = uilabel(app.LeftScroll, ...
                'Text', txt, ...
                'FontSize', 9, ...
                'FontWeight','bold', ...
                'FontColor',[0.35 0.4 0.55]);
            lbl.Layout.Row = row;
            lbl.Layout.Column = 1;
        end

        function lbl = infoLabel(app, txt, row)
            lbl = uilabel(app.LeftScroll, ...
                'Text', txt, ...
                'FontSize', 10, ...
                'FontName','Courier New', ...
                'FontColor',[0.45 0.5 0.62]);
            lbl.Layout.Row = row;
            lbl.Layout.Column = 1;
        end

        function labelInGrid(~, g, txt, r, c)
            lbl = uilabel(g,'Text',txt,'FontColor',[0.45 0.5 0.62],'FontSize',10);
            lbl.Layout.Row=r; lbl.Layout.Column=c;
        end

        function ef = numField(~, parent, val, lo, hi, r, c)
            ef = uieditfield(parent, 'numeric', ...
                'Value', val, 'Limits', [lo hi], ...
                'FontColor',[0.85 0.88 0.95], ...
                'BackgroundColor',[0.11 0.13 0.18], ...
                'FontName','Courier New','FontSize',11);
            ef.Layout.Row=r; ef.Layout.Column=c;
        end

        function [sl, valLbl, nextRow] = sliderRow(app, labelTxt, lo, hi, defVal, row)
            % label row
            rowLbl = uilabel(app.LeftScroll,'Text',labelTxt, ...
                'FontSize',10,'FontColor',[0.45 0.5 0.62]);
            rowLbl.Layout.Row = row; row=row+1;

            % slider + value label in sub-grid
            sg = uigridlayout(app.LeftScroll,[1 2]);
            sg.Layout.Row=row; row=row+1;
            sg.ColumnWidth={'1x',40};
            sg.Padding=[0 0 0 0]; sg.BackgroundColor=[0.07 0.08 0.11];

            sl = uislider(sg);
            sl.Limits  = [lo hi];
            sl.Value   = defVal;
            sl.Layout.Row=1; sl.Layout.Column=1;
            sl.FontColor = [0.45 0.5 0.62];
            sl.FontSize = 9;
            sl.MajorTicks=[];
            sl.MinorTicks=[];

            valLbl = uilabel(sg,'Text',sprintf('%.2f',defVal), ...
                'FontName','Courier New','FontSize',10, ...
                'FontColor',[0.29 0.94 0.69],'HorizontalAlignment','right');
            valLbl.Layout.Row=1; valLbl.Layout.Column=2;

            sl.ValueChangedFcn = @(s,~) set(valLbl,'Text',sprintf('%.2f',s.Value));
            nextRow = row;
        end

        function divider(app, row)
            lbl = uilabel(app.LeftScroll,'Text','','BackgroundColor',[0.15 0.17 0.24]);
            lbl.Layout.Row = row;
        end

    end % private methods

    % ══════════════════════════════════════════════════════════════════════
    methods (Access = public)
        function app = ROIBlinkOverlayApp()
            app.buildUI();
            if nargout == 0
                % don't assign to ans so figure stays open
            end
        end
    end

end % classdef


% ════════════════════════════════════════════════════════════════════════════
% LOCAL HELPERS  (used by callCoreWithProgress)
% ════════════════════════════════════════════════════════════════════════════
function S = local_stat_at(stat, ii)
    if builtin('iscell',stat), S = stat{1,ii}; else, S = stat(ii); end
end

function [Ly,Lx,zeroBased] = local_infer_image_size(stat, iscellFlags)
    nROIs = size(iscellFlags,1);
    allY=[]; allX=[];
    for ii=1:nROIs
        S=[];
        if builtin('iscell',stat)
            if ii<=numel(stat)&&~isempty(stat{1,ii}), S=stat{1,ii}; end
        else
            if ii<=numel(stat)&&~isempty(stat(ii)), S=stat(ii); end
        end
        if ~isempty(S)&&isfield(S,'ypix')&&isfield(S,'xpix') ...
                     &&~isempty(S.ypix)&&~isempty(S.xpix)
            allY=[allY;S.ypix(:)]; allX=[allX;S.xpix(:)]; %#ok<AGROW>
        end
    end
    if isempty(allY)||isempty(allX)
        error('Could not infer image size: stat entries missing ypix/xpix.');
    end
    zeroBased = (min(allY)==0)||(min(allX)==0);
    Ly = max(allY)+double(zeroBased);
    Lx = max(allX)+double(zeroBased);
end

function st = local_get_spikes(spkBag, k, isSpkCell, isSpkStruct)
    if isSpkCell
        % Cell array: each element is one unit's spike times
        st = spkBag{k};

    elseif isSpkStruct
        % Could be:
        %   (a) struct array  — spkBag(k).spks
        %   (b) scalar struct — spkBag.spks is a cell array, index with {k}
        %                     — spkBag.spks is a matrix, index with (k,:) or row k

        cands = {'spks','t','times','spike_times','spikeTimes'};
        st = [];
        for ii = 1:numel(cands)
            fn = cands{ii};
            if ~isfield(spkBag, fn), continue; end

            val = spkBag.(fn);   % works for both scalar struct and struct array element

            if numel(spkBag) > 1
                % Struct array: spkBag(k).fn
                st = spkBag(k).(fn);
            elseif iscell(val)
                % Scalar struct, cell array field: val{k}
                st = val{k};
            elseif isnumeric(val) && size(val,1) >= k
                % Scalar struct, numeric matrix: row k
                st = val(k,:);
                st = st(~isnan(st) & st > 0);
            else
                st = val;  % fallback: return as-is
            end
            break;
        end

    else
        st = [];
    end

    if isempty(st), st = []; else, st = st(:)'; end
end
function tf = endsWith(str, suffix)
    if builtin('isfloat',str), tf=false; return; end
    if numel(str) < numel(suffix), tf=false; return; end
    tf = strcmp(str(end-numel(suffix)+1:end), suffix);
end
