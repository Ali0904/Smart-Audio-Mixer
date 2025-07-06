function advanced_audio_mixer()
    f = figure('Position', [100, 100, 800, 700], 'MenuBar', 'none', ...
               'Name', 'Advanced Audio Mixer', 'NumberTitle', 'off', ...
               'Resize', 'off', 'Color', [0.95 0.95 0.95]);

    audio_data = struct();
    fs = 8000;
    audio_names = {'Train', 'Chirp', 'Gong', 'Splat', 'Handel', 'Laughter', 'Your Voice'};
    load_audio_files();

    control_panel = uipanel('Title', 'Audio Mixer Controls', 'Position', [0.02, 0.55, 0.46, 0.42], ...
                            'BackgroundColor', [0.95 0.95 0.95]);

    uicontrol(control_panel, 'Style', 'text', 'Position', [20, 250, 150, 20], ...
              'String', 'Recording Duration (sec):', 'BackgroundColor', [0.95 0.95 0.95]);
    duration_edit = uicontrol(control_panel, 'Style', 'edit', 'Position', [180, 250, 50, 25], ...
                              'String', '2', 'BackgroundColor', 'white');

    % Create volume sliders for all 7 audio sources
    volume_sliders = gobjects(7,1);
    volume_texts = gobjects(7,1);
    start_y = 210;
    spacing = 25;
    for i = 1:7
        y_pos = start_y - (i-1)*spacing;
        uicontrol(control_panel, 'Style', 'text', 'Position', [20, y_pos, 100, 20], ...
                  'String', [audio_names{i} ':'], 'BackgroundColor', [0.95 0.95 0.95]);
        volume_sliders(i) = uicontrol(control_panel, 'Style', 'slider', ...
            'Position', [120, y_pos, 150, 20], ...
            'Min', 0, 'Max', 1, 'Value', 0.5, ...
            'BackgroundColor', [0.9 0.9 0.9], ...
            'Tag', num2str(i));
        volume_texts(i) = uicontrol(control_panel, 'Style', 'text', ...
            'Position', [280, y_pos, 50, 20], ...
            'String', '0.5', 'BackgroundColor', [0.95 0.95 0.95]);
    end

    for i = 1:7
        volume_sliders(i).Callback = @(src,~) update_volume_text(src, volume_texts(i));
    end

    % Master volume slider
    uicontrol(control_panel, 'Style', 'text', 'Position', [20, 30, 100, 20], ...
              'String', 'Master Volume:', 'FontWeight', 'bold', 'BackgroundColor', [0.95 0.95 0.95]);
    master_slider = uicontrol(control_panel, 'Style', 'slider', 'Position', [120, 30, 150, 20], ...
                              'Min', 0, 'Max', 1, 'Value', 1.0, 'BackgroundColor', [0.9 0.9 0.9]);
    master_text = uicontrol(control_panel, 'Style', 'text', 'Position', [280, 30, 50, 20], ...
                            'String', '1.0', 'BackgroundColor', [0.95 0.95 0.95]);
    master_slider.Callback = @(src,~) update_volume_text(src, master_text);

    % Visualization Panel
    plot_panel = uipanel('Title', 'Signal Visualization', 'Position', [0.02, 0.05, 0.96, 0.48], ...
                         'BackgroundColor', 'white');
    ax_input = subplot(2,1,1, 'Parent', plot_panel);
    ax_output = subplot(2,1,2, 'Parent', plot_panel);

    % Control Buttons
    uicontrol('Style', 'pushbutton', 'String', 'Record', 'Position', [600, 420, 150, 30], ...
              'FontWeight', 'bold', 'BackgroundColor', [0.8 0.9 0.8], 'Callback', @record_voice);
    uicontrol('Style', 'pushbutton', 'String', 'Mix Audio', 'Position', [600, 380, 150, 30], ...
              'BackgroundColor', [0.8 0.8 0.9], 'Callback', @mix_audio);
    uicontrol('Style', 'pushbutton', 'String', 'Play Input', 'Position', [600, 340, 150, 30], ...
              'BackgroundColor', [0.9 0.8 0.8], 'Callback', @play_input);
    uicontrol('Style', 'pushbutton', 'String', 'Play Mix', 'Position', [600, 300, 150, 30], ...
              'BackgroundColor', [0.8 0.9 0.9], 'Callback', @play_mix);
    uicontrol('Style', 'pushbutton', 'String', 'Save Mix', 'Position', [600, 120, 150, 30], ...
              'BackgroundColor', [0.9 0.8 0.8], 'Callback', @save_mix);
    uicontrol('Style', 'pushbutton', 'String', 'Exit', 'Position', [600, 20, 150, 30], ...
              'Callback', @(~,~) close(f));

    mixer_state = struct('has_recorded', false, 'has_mixed', false);

    function update_volume_text(slider, text_control)
        if isgraphics(text_control)
            set(text_control, 'String', num2str(get(slider, 'Value'), '%.2f'));
        end
    end

    function load_audio_files()
        disp('Loading audio files...');
        files = {'train.mat', 'chirp.mat', 'gong.mat', 'splat.mat', 'handel.mat', 'laughter.mat'};
        fields = {'train', 'chirp', 'gong', 'splat', 'handel', 'laughter'};
        for i = 1:length(files)
            try
                file_path = which(files{i});
                if isempty(file_path), error('File not found'); end
                loaded = load(file_path);
                audio_data.(fields{i}) = loaded.y(:)'; % row vector
            catch
                warning('Could not load %s. Using silence.', files{i});
                audio_data.(fields{i}) = zeros(1, fs*2);
            end
        end
        disp('Audio files loaded.');
    end

    function record_voice(~, ~)
        duration = str2double(get(duration_edit, 'String'));
        if isnan(duration) || duration <= 0
            errordlg('Enter a valid duration.', 'Input Error');
            return;
        end
        rec = audiorecorder(fs, 16, 1);
        msg = msgbox('Recording... Speak now', 'Recording');
        recordblocking(rec, duration);
        if ishandle(msg), close(msg); end
        audio_data.your_voice = getaudiodata(rec)';
        mixer_state.has_recorded = true;
        plot_signals();
        msgbox('Recording complete!', 'Done');
    end

    function play_input(~, ~)
        if ~mixer_state.has_recorded
            msgbox('Please record your voice first.', 'Warning');
            return;
        end
        sound(audio_data.your_voice, fs);
    end

    function play_mix(~, ~)
        if ~mixer_state.has_mixed
            msgbox('No mixed audio available. Please mix first.', 'Warning');
            return;
        end
        sound(audio_data.mixed, fs);
    end

    function save_mix(~, ~)
        if ~mixer_state.has_mixed
            msgbox('Mix the audio first.', 'Warning');
            return;
        end
        [file, path] = uiputfile('*.wav', 'Save Mixed Audio');
        if isequal(file, 0), return; end
        audiowrite(fullfile(path, file), audio_data.mixed', fs);
        msgbox('Audio saved.', 'Done');
    end

    function mix_audio(~, ~)
        if ~mixer_state.has_recorded
            msgbox('Please record your voice first.', 'Warning');
            return;
        end

        sources = {'train', 'chirp', 'gong', 'splat', 'handel', 'laughter', 'your_voice'};
        volumes = arrayfun(@(s) get(s, 'Value'), volume_sliders);
        master_volume = get(master_slider, 'Value');

        target_length = length(audio_data.your_voice);
        mixed = zeros(1, target_length);

        for i = 1:7
            if isfield(audio_data, sources{i}) && ~isempty(audio_data.(sources{i}))
                source = audio_data.(sources{i});
            else
                source = zeros(1, fs);
            end
            source = source(:)';
            if length(source) < target_length
                source = [source, zeros(1, target_length - length(source))];
            else
                source = source(1:target_length);
            end
            mixed = mixed + source * volumes(i);
        end

        if max(abs(mixed)) > 0
            mixed = mixed / max(abs(mixed));
        end
        mixed = mixed * master_volume;

        audio_data.mixed = mixed;
        mixer_state.has_mixed = true;
        plot_signals();
        msgbox('Audio mixing complete!', 'Success');
    end

    function plot_signals()
        cla(ax_input);
        if mixer_state.has_recorded
            t = (0:length(audio_data.your_voice)-1)/fs;
            plot(ax_input, t, audio_data.your_voice, 'b');
            title(ax_input, 'Your Voice (Input Signal)');
            xlabel(ax_input, 'Time (s)');
            ylabel(ax_input, 'Amplitude');
            grid(ax_input, 'on');
        end
        cla(ax_output);
        if mixer_state.has_mixed
            t = (0:length(audio_data.mixed)-1)/fs;
            plot(ax_output, t, audio_data.mixed, 'r');
            title(ax_output, 'Mixed Output Signal');
            xlabel(ax_output, 'Time (s)');
            ylabel(ax_output, 'Amplitude');
            grid(ax_output, 'on');
        end
        drawnow;
    end
end
