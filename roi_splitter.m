function roi_splitter
    global ct_info
    global ct
    global ct_roi
    global fn;
    global cross_split;
    screenSize = get(0, 'Screensize');

    
    prepareEnviroment() 
    roi_splitter_script_tobias()
    

end

function mainFigure = drawLogFigure(logText)
    mainFigure = figure('Tag',mfilename,...
        'MenuBar','None',...
        'IntegerHandle','off',...
        'Resize','on',...
        'NumberTitle','off',...
        'Name',sprintf('Roi Splitter - Version 0.0.1dev'),...
        'Visible','on',...
        'Position',[400,100,1050,screenSize(4) - 120] ,... %400,50,1050,700
        'Tag','mainfig');
end

function prepareEnviroment()  
    missingDependency = checkForDependencies();
    
    
    pathCell = regexp(path, pathsep, 'split');
    
    %if ~findstr(pathCell{1}, 'dependencies')
        if ~missingDependency
            init_toolbox(['dependencies' filesep 'toolbox']);
            addpath(['dependencies'  filesep 'xlwrite']);
            addpath(['dependencies' filesep 'NIfTI_20140122/']);
            
            xlwriteFolder = ['dependencies' filesep 'xlwrite'];
            
            javaaddpath([xlwriteFolder filesep 'poi_library' filesep 'poi-3.8-20120326.jar']);
            javaaddpath([xlwriteFolder filesep 'poi_library' filesep 'poi-ooxml-3.8-20120326.jar']);
            javaaddpath([xlwriteFolder filesep 'poi_library' filesep '/poi-ooxml-schemas-3.8-20120326.jar']);
            javaaddpath([xlwriteFolder filesep 'poi_library' filesep 'xmlbeans-2.3.0.jar']);
            javaaddpath([xlwriteFolder filesep 'poi_library' filesep '/dom4j-1.6.1.jar']);
            javaaddpath([xlwriteFolder filesep 'poi_library' filesep '/stax-api-1.0.1.jar']);
            
        else
            disp('raise exception')
        end
   % end
end

function init_toolbox(base_path)
    addpath([base_path filesep,'channels']);
    addpath([base_path filesep,'classify']);
    addpath([base_path filesep,'detector']);
    addpath([base_path filesep,'external']);
    addpath([base_path filesep,'filters']);
    addpath([base_path filesep,'images']);
    addpath([base_path filesep,'matlab']);
    addpath([base_path filesep,'videos']);
end


function missingDependency = checkForDependencies()
    listOfFoldersAndFiles = dir('.');
    
    missingDependency = true;
    
    nElements = length(listOfFoldersAndFiles);
    
    for element = 1:nElements
        currentElementName = listOfFoldersAndFiles(element).name;
        
        if strcmp(currentElementName, 'dependencies')
            insideFoldersAndFiles = dir('dependencies');
            nInsideElements = length(insideFoldersAndFiles);
            neededFiles = {};
            counter = 1;
               for index = 1:nInsideElements
                   if strcmp(insideFoldersAndFiles(index).name, 'toolbox') ||...
                       strcmp(insideFoldersAndFiles(index).name, 'xlwrite') ||...
                       strcmp(insideFoldersAndFiles(index).name, 'NIfTI_20140122/')
                       neededFiles{counter} = insideFoldersAndFiles(index).name;
                       counter = counter + 1;
                   end
               end
            if cellfun(@strcmp, {'toolbox', 'xlwrite'}, neededFiles)
                missingDependency = false;
            end
        else
           
        end

    end
    
end


function roi_splitter_script_tobias()
    global ct_info
    global ct
    global ct_roi
    global fn;
    global cross_split

    dirName = uigetdir('Select the target folder');
    
    if dirName
        
        if ismac==1,
            delim = '/';
        else
            delim = '\\';
        end
        
        [ct, ct_info, ct_roi, fn] = loadCTFromDICOM(dirName);        
        
        
        ct_mask = convertROItoMask(ct, ct_roi);
        %if length(unique(ct_mask(:)))==1,
        %    [roi_split,cross_split] = ROI_Splitter_Tobias(ct);
        %else
            [showNewFig, figHandles] = checkIfFigureAlreadyExists();
            if showNewFig
                f = figure('Visible','on','Name','Show Slice',...
               'Position',[360,500,600,600],'resize','on','units','characters');
            else
                f = figHandles;
            end
            [roi_split, cross_split] = ROI_Splitter_Tobias(ct, [], f, dirName);
       % end
        

    end
end

function [showNewFig, figHandles] = checkIfFigureAlreadyExists()
%Get the handle of all opnened figures
figHandles = get(0,'Children');

if isempty(figHandles)
    showNewFig = 1;
else
    currentFigureName = get(figHandles, 'Name');
    if strcmp(currentFigureName, 'Show Slice');
        showNewFig = 0;
    else
        showNewFig = 1;
    end

end
    
end

function [ct, ct_info, ct_roi, dirName] = loadCTFromDICOM(dirName)
    
     
    if nargin < 3
        warningOverlap = true;
    end
    
    if nargin < 4
        verbose = true;
    end

    % If required, let the user select the directory graphically.
    % Else, the user provides the directory name explicitly.
   
    ct = [];
    ct_info = {};
    ct_roi = {};
    
    files = dir(fullfile(dirName,'*.dcm'));
    poly_files = dir(fullfile(dirName,'*_poly.mat'));
    poly_count = 1;
    
     %# remove all folders
     isBadFile = cat(1,files.isdir); %# all directories are bad
     
     %# loop to identify hidden files
     for iFile = find(~isBadFile)' %'# loop only non-dirs
         %# on OSX, hidden files start with a dot
         isBadFile(iFile) = strcmp(files(iFile).name(1),'.');
         if ~isBadFile(iFile) && ispc
             %# check for hidden Windows files - only works on Windows
             [~,stats] = fileattrib(fullfile(dirName,files(iFile).name));
             if stats.hidden
                 isBadFile(iFile) = true;
             end
         end
     end
     
     %# remove bad files
     files(isBadFile) = [];
     
     numberFiles = length(files);
     
     if numberFiles==0,
         display(sprintf('loadCTFromDICOM: No DICOM files found in directory %s. Exiting.',...
             dirName));
         return;
     end
    
    fn = strcat(dirName,'/',files(1).name);
    if ~isdicom(fn)
        display(sprintf('loadCTFromDICOM: DICOM file %s seems to be corrupted. Exiting.',...
                fn));
        return;
    end
    ct_1 = dicominfo(fn);
    
    use_slice_location = true;
    sliceLocations = zeros(1,numberFiles);
    
    ct_info = cell(1, numberFiles);
    
    for k=1:numberFiles,
        fn = strcat(dirName,'/',files(k).name);
        if ~isdicom(fn)
            display(sprintf('loadCTFromDICOM: DICOM file %s seems to be corrupted. Exiting.',...
                fn));
            return;
        end
        ct_i = dicominfo(fn);
        ct_info{k} = ct_i;
        if ~isfield(ct_i, 'SliceLocation'),
            %display('loadCTFromDICOM: Error - File has no field SliceLocation. Nothing is loaded.');
            %return;
            display('loadCTFromDICOM: Error - File has no field SliceLocation.');
            use_slice_location = false;
            break;
        end
        %ct_i = dicominfo(strcat(dirName,'/',files(k).name));
        sliceLocations(k) = ct_i.SliceLocation;
    end
    
    if use_slice_location
        last_pos = ct_1.SliceLocation;
        new_pos = 0;
        [~, I] = sort(sliceLocations,'ascend');
        files = files(I);
        ct_info_old = ct_info;
        for k=1:length(ct_info),
            ct_info{k} = ct_info_old{I(k)};
        end
    end
    
    ct = zeros(ct_info{1}.Rows,ct_info{1}.Columns,numberFiles);
    ct_roi = cell(1, numberFiles);
    
    for k=1:numberFiles,
        ct(:,:,k) = dicomread(strcat(dirName,'/',files(k).name));
        %ct_i = dicominfo(strcat(dirName,'/',files(k).name));
        %ct_info{k} = ct_i;
        ct_i = ct_info{k};
        
        if use_slice_location
            if k>1
                new_pos = ct_i.SliceLocation;
                if warningOverlap && verbose
                    if abs(new_pos - last_pos) ~= ct_i.SliceThickness
                        display(sprintf('loadCTFromDICOM: Slice overlap detected between slices %d and %d (%d mm, SliceThickness = %d)',...
                                        k-1, k, abs(new_pos - last_pos), ct_i.SliceThickness));
                    end
                end
            end
            last_pos = ct_i.SliceLocation;
        end
        
        if isfield(ct_i, 'Private_6001_10c0')
            roi_info = ct_i.Private_6001_10c0.Item_1;
            count = 1;
            fields = fieldnames(roi_info);
            for l=1:length(fields),
                f = fields{l};
                if ~isempty(strfind(f,'_10b0'))
                    if strcmp(roi_info.(f),'POLYGON')
                        ind = textscan(f,'%s','delimiter','_');
                        poly_roi = roi_info.(strcat(ind{1}{1},'_',ind{1}{2},'_10ba'));
                        ct_roi{k}{count} = [poly_roi(1:2:end-1) poly_roi(2:2:end-1)];
                        count = count+1;
                    end
                end
            end
            if count==1
                ct_roi{k} = {};
            end
            
%             count = 1;
%             for l = 1:90
%                l_h = lower(dec2hex(l));
%                if length(l_h)==1
%                    l_h = strcat('0',l_h);
%                end
%                f = strcat('Private_60',l_h);
%                if isfield(roi_info, strcat(f,'_1000'))
%                   if strcmp(roi_info.(strcat(f,'_10b0')),'POLYGON')
%                      poly_roi = roi_info.(strcat(f,'_10ba'));
%                      ct_roi{k}{count} = [poly_roi(1:2:end-1) poly_roi(2:2:end-1)];
%                      count = count+1;
%                   end
%                end
%             end
%             if count==1
%                 ct_roi{k} = {};
%             end
            
            
%             for l = 1:9
%                f = strcat('Private_600',int2str(l));
%                if isfield(roi_info, strcat(f,'_1000'))
%                   if strcmp(roi_info.(strcat(f,'_10b0')),'POLYGON')
%                      poly_roi = roi_info.(strcat(f,'_10ba'));
%                      ct_roi{k}{count} = [poly_roi(1:2:end-1) poly_roi(2:2:end-1)];
%                      count = count+1;
%                   end
%                end
%             end
%             for l = 'a':'f'
%                f = strcat('Private_600',l);
%                if isfield(roi_info, strcat(f,'_1000'))
%                   if strcmp(roi_info.(strcat(f,'_10b0')),'POLYGON')
%                      poly_roi = roi_info.(strcat(f,'_10ba'));
%                      ct_roi{k}{count} = [poly_roi(1:2:end-1) poly_roi(2:2:end-1)];
%                      count = count+1;
%                   end
%                end
%             end
        else
            fn_poly = strcat(dirName,'/',strtok(files(k).name,'.'),'_poly.mat');
            if exist(fn_poly,'file')
                S = load(fn_poly);
                ct_roi{k} = S.slicePoly;
            else
                ct_roi{k} = {};
                if verbose
                    display(strcat('No ROI information in slice ', int2str(k)));
                end
            end
        end
    end
    
    ct = int16(ct)*ct_info{1}.RescaleSlope + ct_info{1}.RescaleIntercept;
    
    display(sprintf('loadCTFromDICOM: Succesfully loaded %d slices from directory %s',...
                    numberFiles, dirName));
 
end

function [roi_split, cross_split] = ROI_Splitter_Tobias(volume, seg, f, projectPath)
global ct_info
global ct
global ct_roi
global fn;
global cross_split
global listWithIndexes
global niiWithOutSegmentation
global niiWithSegmentation

%Open NII with segmentation
niiFileNameWithSegmentation = dir([projectPath filesep '*.nii']);
niiWithSegmentation = load_nii_with_rotation([projectPath filesep niiFileNameWithSegmentation.name]);

%Open NII WITHOUT segmentation
tenSlicesPath = getTenSlicesPath(projectPath);
niiFileNameWithOutSegmentation = dir([tenSlicesPath filesep '*.nii']);
niiWithOutSegmentation = load_nii_with_rotation([tenSlicesPath...
    filesep niiFileNameWithOutSegmentation.name]);

listWithIndexesPath = dir([tenSlicesPath filesep '*positions.txt']);
%Add 1 to convert to Matlab indexes.
listWithIndexes = importdata([tenSlicesPath filesep listWithIndexesPath.name]) + 1;

roi_split = niiWithSegmentation.img;
seg = niiWithSegmentation.img;

%if nargin==1,
    %seg = zeros(size(volume));
    inside_mask = computeThoraxInsideMask(volume>-500 & volume<150);
%else
%    inside_mask = seg;
%end

% Create an axes object to show which color is selected
Img = axes('Parent',f,'units','normalized',...
           'Position',[.05 .031 .85 .85]);
% Create a slider to display the images
slider1 = uicontrol('Style', 'slider', 'Parent', f, 'String', 'Image No.', 'Units', 'normalized','Callback', @slider_callback, ...
     'Position', [.12 .001 .85 .03]);

text1 = uicontrol('style','text','parent',f,'string','slice number','units','pixel','position',[50 5 100 20]);

if verLessThan('matlab', '8.4')
    handle.listener(slider1,'ActionEvent',@slider_callback);
else
    addlistener(slider1, 'ContinuosValueChange', @slider_callback);
end
set(f, 'KeyPressFcn', @keypress_fct);

button_load = uicontrol('Style', 'pushbutton', 'String', 'Load DICOM',...
        'Units', 'Normalized', 'Position', [0.05 0.9 0.15 0.05],...
        'Callback', @buttonpress_load_fct);  
button_save_matlab = uicontrol('Style', 'pushbutton', 'String', 'Save Cross',...
        'Units', 'Normalized', 'Position', [0.20 0.9 0.15 0.05],...
        'Callback', @buttonpress_save_mtlb_fct); 
%button_save_excel = uicontrol('Style', 'pushbutton', 'String', 'Open Gui Slicer',...
%        'Units', 'Normalized', 'Position', [0.20 0.9 0.25 0.05],...
%        'Callback', @buttonpress_save_excel_fct); 
   

button_cross = uicontrol('Style', 'pushbutton', 'String', 'Set Cross',...
        'Units', 'Normalized', 'Position', [0.35 0.9 0.15 0.05],...
        'Callback', '',...
        'Enable','Off');  

movegui(Img,'onscreen')% To display application onscreen
movegui(Img,'center') % To display application in the center of screen

currentSlice = 1;

h_ct = imshow(volume(:,:,currentSlice),[]);

yellow_image = cat(3,ones(size(volume,1)),ones(size(volume,1)), zeros(size(volume,1)));

hold on; h_im = imshow(yellow_image); hold off;
set(h_im,'AlphaData',0.25*seg(:,:,currentSlice));
set(text1,'String',num2str(currentSlice));  % set slice number in gui

set(findobj(gcf,'type','axes'),'hittest','on');

set(slider1, 'Min', 1);
set(slider1, 'Max', size(volume,3));
set(slider1, 'value', currentSlice);
set(slider1, 'SliderStep', [1/size(volume,3) 1/size(volume,3)]);

is_split = zeros(1,size(volume,3));
cross_split = zeros(size(volume));

for k=1:size(volume,3),
    if sum(sum(seg(:,:,k)))==0,
         %thorax_mask = volume(:,:,cur_slice)>-800 & volume(:,:,cur_slice)<500;
         bb = regionprops(inside_mask(:,:,k),'boundingbox');
         bb = round(bb.BoundingBox);
         bb = [bb 0];
     else
         bb = regionprops(seg(:,:,k),'boundingbox');
         bb = round(bb.BoundingBox);
         bb = [bb 0];
     end
     rect_pos = bb;
     pos = bb;
     x = pos(1);
     y = pos(2);
     w = pos(3);
     h = pos(4);
     %th = pos(5)*pi/180;
     A = [x; y];
     B = [x+w;y];
     C = [x+w;y+h];
     D = [x;y+h];
     M = 0.25*(A+B+C+D);
     %R = rotationMatrix(th);
     A_ = A;
     B_ = B;
     C_ = C;
     D_ = D;
     %A_ = R*(A-M)+M;
     %B_ = R*(B-M)+M;
     %C_ = R*(C-M)+M;
     %D_ = R*(D-M)+M;
     A1 = 0.5*(A_+D_);
     A2 = 0.5*(A_+B_);
     A3 = 0.5*(B_+C_);
     A4 = 0.5*(D_+C_);
     P1 = [A_, A2, M,  A1]';
     P2 = [A2, B_, A3, M]';
     P3 = [M,  A3, C_, A4]';
     P4 = [A1, M,  A4, D_]';
     P1M = poly2mask(P1(:,1), P1(:,2),size(volume,1),size(volume,2));
     P2M = poly2mask(P2(:,1), P2(:,2),size(volume,1),size(volume,2));
     P3M = poly2mask(P3(:,1), P3(:,2),size(volume,1),size(volume,2));
     P4M = poly2mask(P4(:,1), P4(:,2),size(volume,1),size(volume,2));
     mm_split = zeros(size(seg(:,:,k)));
     mm_split(P1M>0) = 1;
     mm_split(P2M>0) = 2;
     mm_split(P3M>0) = 3;
     mm_split(P4M>0) = 4;
     if nargin==1,
         mm_split(inside_mask(:,:,k)==0)=0;
     else
         mm_split( seg(:,:,k) == 0 ) = 0;
     end
     roi_split(:,:,k) = mm_split;
     is_split(k) = 1;
     
     cs = zeros(size(cross_split,1),size(cross_split,2));
     if A1(2)-2<1,
         A1(2)=3;
     end
     if A1(2)+2>size(cross_split,1)
         A1(2) = size(cross_split,1)-2;
     end
     if A2(1)-2<1
         A2(1)=3;
     end
     if A2(1)+2>size(cross_split,2)
         A2(1) = size(cross_split,1)-2;
     end
     if A3(1)>size(cross_split,1)
         A3(1) = size(cross_split,1);
     end
     if A4(2)>size(cross_split,2)
         A4(2) = size(cross_split,2);
     end
     cs(round(A1(2))-2 : round(A1(2))+2, round(A1(1)):round(A3(1))) = 1;
     cs(round(A2(2)):round(A4(2)), round(A2(1))-2 : round(A2(1))+2) = 1;
     cross_split(:,:,k) = cs;
 end

 
%  for k=1:size(seg,3)
%     sl = seg(:,:,k);
%     if numel(unique(sl(:)))==5,
%        is_split(k)=1;
%        roi_split(:,:,k) = sl;
%     end
%  end
 
 h_rect = -1;
 h_api = -1;
 
 h_line1 = -1;
 h_line2 = -1;
 
 rect_pos = [];
 
 updateMask();
 
 %waitfor(f);
 
 
    function updateMask()
        if ishandle(h_im)
            delete(h_im);
        end
        if ishandle(h_rect)
            delete(h_rect);
        end
        if is_split(currentSlice)==0

            hold on; h_im = imshow(yellow_image); hold off;   % show segmentation
            set(h_im,'AlphaData',0.25*seg(:,:,currentSlice)); % make transparent
        else
           hold on; h_im = imshow(label2rgb(roi_split(:,:,currentSlice))); hold off;
           set(h_im, 'AlphaData', 0.2*(roi_split(:,:,currentSlice)>0));
        end
        
        
        green_image = cat(3,zeros(size(volume,1)),ones(size(volume,1)), zeros(size(volume,1)));
        
        hold on; h = imshow(green_image); hold off;
        set(h,'AlphaData',0.25*cross_split(:,:,currentSlice));
        removeCrossLinesHandles(0);
        
    end


    function keypress_fct(src, event)
        switch event.Key
            case 's'
            perform_split(currentSlice, h_im);
            case 'x'
           updateMask(); 
            case 'rightarrow'
            if uint32(get(slider1,'value'))<size(volume,3)
                if ishandle(h_rect)
                    delete(h_rect);
                end
                set(slider1,'value',uint32(get(slider1,'value'))+1);
                currentSlice = uint32(get(slider1,'value'));
                axes(Img);
                h_ct = imshow(volume(:,:,currentSlice),[]);
                set(text1,'String',num2str(currentSlice));  % set slice number in gui
                updateMask();
            end
            case 'leftarrow'
            if uint32(get(slider1,'value'))>1
                if ishandle(h_rect)
                    delete(h_rect);
                end
                set(slider1,'value',uint32(get(slider1,'value'))-1);
                currentSlice = uint32(get(slider1,'value'));
                axes(Img);
                h_ct = imshow(volume(:,:,currentSlice),[]);
                set(text1,'String',num2str(currentSlice));  % set slice number in gui
                updateMask();
            end
        end
    end

    function buttonpress_load_fct(h, eventdata)
        roi_splitter_script_tobias();
    end

    function buttonpress_save_mtlb_fct(h, eventdata)
        
        
        %
        %
        %         s_uid = ct_info{1}.SeriesInstanceUID;
        %         cross_split = cross_split;
        %         folder_name = textscan(fn,'%s','delimiter',filesep);
        %         folder_name = folder_name{:};
        %         folder_name = folder_name(end);
        %         folder_name = folder_name{:};
        %
        %         ct_info_resume = ct_info{1};
        %
        %         save(strcat(fn,filesep,folder_name,'_roi_split_tobias.mat'),...
        %             's_uid', 'roi_split', 'cross_split', 'ct_info_resume');
        
        
        
        
        %Choose base .NII file
        %[niiFileName, niiPathName] = uigetfile('*.nii', 'Select the base .nii file');
        
        %if niiFileName
            %nii = load_nii([niiPathName niiFileName]);
                        %
            
            %mask = zeros(size(nii.img));
            %
            %
            % % This is only necessary if there is any data in nii.img, which in this
            % % setting there is not.
            %for k=1:size(nii.img,3),
            %    mask(:,:,k) = fliplr(imrotate(nii.img(:,:,k),90));
            %end
            %
            %
            %     % Do stuff, result is mask_final
            %     % Fill in the cross here.
            %     % Could be as easy as
            %     % mask_final = mask_cross;
            mask_final = cross_split;
            
            exportDir = uigetdir('Select target place to save all results');
            
            if exportDir
                prompt = {'Select results base name:'};
                dlg_title = 'Save results';
                num_lines = 1;
                def = {'results'};
                
                answer = inputdlg(prompt,dlg_title,num_lines,def);
                
                if ~isempty(answer{1})
                    
                    mask_export = zeros(size(mask_final));
                    for k=1:size(mask_export,3),
                        mask_export(:,:,k) = imrotate(fliplr(mask_final(:,:,k)),-90);
                    end
                    niiWithSegmentation.img = uint8(mask_export);
                    
                    
                    save_nii(niiWithSegmentation,[exportDir filesep answer{1} '_all_slices_crosses.nii']);
                    
                    
                    maskExportTenSlices = zeros(size(mask_final, 1),...
                        size(mask_final, 2), 10);
                    
                    counter = 1;
                    for k = listWithIndexes',
                        maskExportTenSlices(:,:,counter) = imrotate(fliplr(mask_final(:,:,k)),-90);
                        counter = counter + 1;
                    end
                    niiWithOutSegmentation.img = uint8(maskExportTenSlices);                    
                    
                    save_nii(niiWithOutSegmentation,[exportDir filesep answer{1} '_10Slices_crosses.nii']);
                        
                    
                    s_uid = ct_info{1}.SeriesInstanceUID;
                    cross_split = cross_split;
                    folder_name = textscan(fn,'%s','delimiter',filesep);
                    folder_name = folder_name{:};
                    folder_name = folder_name(end);
                    folder_name = folder_name{:};
                    
                    ct_info_resume = ct_info{1};
                    
                    %             [fn_export, path_export] = uiputfile('*.mat', 'Select target place to save the .MAT file');
                    
                    save([exportDir filesep answer{1} '.mat'],...
                        's_uid', 'roi_split', 'cross_split', 'ct_info_resume');
                    
                    quantitativeAnalysis(ct(:, :, listWithIndexes'),...
                        ct_info(listWithIndexes), roi_split(:, :, listWithIndexes'), exportDir, answer{1})
                end
            end
            
    end

    function buttonpress_save_excel_fct(h, eventdata)
        GUI_slicer(ct, false, cross_split, []);
        
    end
 
 
%% Beginning of slider callback function
    function slider_callback(h, eventdata)
        if ishandle(h_rect)
            delete(h_rect);
        end
        currentSlice = uint32(get(slider1,'value'));
        axes(Img);
        h_ct = imshow(volume(:,:,currentSlice),[]);
        set(text1,'String',num2str(currentSlice));  % set slice number in gui 
        
        updateMask();
    end

    function update_split_cb(pos)
        %display('calling update_split_cb');
        rect_pos = pos;
        x = pos(1);
        y = pos(2);
        w = pos(3);
        h = pos(4);
        th = pos(5)*pi/180;
        A = [x; y];
        B = [x+w;y];
        C = [x+w;y+h];
        D = [x;y+h];
        M = 0.25*(A+B+C+D);
        R = rotationMatrix(th);
        A_ = R*(A-M)+M;
        B_ = R*(B-M)+M;
        C_ = R*(C-M)+M;
        D_ = R*(D-M)+M;
        A1 = 0.5*(A_+D_);
        A2 = 0.5*(A_+B_);
        A3 = 0.5*(B_+C_);
        A4 = 0.5*(D_+C_);
        P1 = [A_, A2, M,  A1]';
        P2 = [A2, B_, A3, M]';
        P3 = [M,  A3, C_, A4]';
        P4 = [A1, M,  A4, D_]';  
        P1M = poly2mask(P1(:,1), P1(:,2),size(volume,1),size(volume,2));
        P2M = poly2mask(P2(:,1), P2(:,2),size(volume,1),size(volume,2));
        P3M = poly2mask(P3(:,1), P3(:,2),size(volume,1),size(volume,2));
        P4M = poly2mask(P4(:,1), P4(:,2),size(volume,1),size(volume,2));
        mm_split = zeros(size(seg(:,:,currentSlice)));
        mm_split(P1M>0) = 1;
        mm_split(P2M>0) = 2;
        mm_split(P3M>0) = 3;
        mm_split(P4M>0) = 4;
        %if nargin==1,
            %mm_split(inside_mask(:,:,currentSlice)==0)=0;
        %else
            mm_split( seg(:,:,currentSlice) == 0 ) = 0;
        %end
        roi_split(:,:,currentSlice) = mm_split;
        is_split(currentSlice) = 1;
        
        if ishandle(h_line1)
            delete(h_line1);
        end
        if ishandle(h_line2)
            delete(h_line2);
        end
        hold on;
        h_line1 = plot([A1(1)+0.1*(A3(1)-A1(1)), A3(1)-0.1*(A3(1)-A1(1))], [A1(2)+0.1*(A3(2)-A1(2)), A3(2)-0.1*(A3(2)-A1(2))], 'g', 'linewidth',2);
        h_line2 = plot([A2(1)+0.1*(A4(1)-A2(1)), A4(1)-0.1*(A4(1)-A2(1))], [A2(2)+0.1*(A4(2)-A2(2)), A4(2)-0.1*(A4(2)-A2(2))], 'g', 'linewidth',2);
        hold off;
        %updateMask();
        
        cs = zeros(size(cross_split,1),size(cross_split,2));
        if A1(2)-2<1,
            A1(2)=3;
        end
        if A1(2)+2>size(cross_split,1)
            A1(2) = size(cross_split,1)-2;
        end
        if A2(1)-2<1
            A2(1)=3;
        end
        if A2(1)+2>size(cross_split,2)
            A2(1) = size(cross_split,1)-2;
        end
        if A3(1)>size(cross_split,1)
            A3(1) = size(cross_split,1);
        end
        if A4(2)>size(cross_split,2)
            A4(2) = size(cross_split,2);
        end
        cs(round(A1(2))-2 : round(A1(2))+2, round(A1(1)):round(A3(1))) = 1;
        cs(round(A2(2)):round(A4(2)), round(A2(1))-2 : round(A2(1))+2) = 1;
        %figure,imshow(cs,[]);
%         display(size(cross_split(:,:,currentSlice)));
%         display(size(cs));
%         display(A1);
%         display(A2);
%         display(A3);
%         display(A4);
        
        cross_split(:,:,currentSlice) = cs;
        
    end

    function perform_split(cur_slice, h)
        
        removeCrossLinesHandles(1);
        
        if ishandle(h_line1)
            delete(h_line1);
        end
        if ishandle(h_line2)
            delete(h_line2);
        end
        %if is_split(cur_slice)
        %    bb = rect_pos;
        %else
            if sum(sum(seg(:,:,cur_slice)))==0,
                %thorax_mask = volume(:,:,cur_slice)>-800 & volume(:,:,cur_slice)<500;
                bb = regionprops(inside_mask(:,:,cur_slice),'boundingbox');
                bb = round(bb.BoundingBox);
                bb = [bb 0];
            else
                bb = regionprops(seg(:,:,cur_slice),'boundingbox');
                bb =round(bb.BoundingBox);
                bb = [bb 0];
            end
       % end
        %h_rect=imrect(gca, bb);
        
        if ishandle(h_rect)
            delete(h_rect);
        end
        [h_rect, h_api] = imRectRot('hParent', gca,...
                           'rotate' , 1,...
                           'pos', bb);
        h_api.setPosSetCb( @(pos) update_split_cb(pos) );
        
       
        
        % Double-click on ROI object to continue;
%fprintf('Before Split %i\n', cur_slice);        
        %wait(h_rect);    
%fprintf('Do Split %i\n', cur_slice);        

%         roi_box = createMask(h_rect, h);
%         roi_box = regionprops(roi_box, 'boundingbox');
%         roi_box = round(roi_box.BoundingBox);
%         
%         bbulx = roi_box(1);
%         bbuly = roi_box(2);
%         bbwx  = roi_box(3);
%         bbwy  = roi_box(4);
%         
%         cx = round(bbulx + (bbwx/2));
%         cy = round(bbuly + (bbwy/2));
%         
%         mm_split = zeros(size(seg(:,:,cur_slice)));
%         mm_split(bbuly:cy     , bbulx:cx      ) = 1;
%         
%         mm_split(bbuly:cy     , cx:bbulx+bbwx ) = 2;
%         mm_split(cy:bbuly+bbwy, bbulx:cx      ) = 3;
%         mm_split(cy:bbuly+bbwy, cx:bbulx+bbwx ) = 4;
%         
%         mm_split( seg(:,:,cur_slice) == 0 ) = 0;
%         
%         roi_split(:,:,cur_slice) = mm_split;
%         is_split(cur_slice) = 1;
        %delete(h_rect);
        %updateMask();
    end
end

function removeCrossLinesHandles(removeCross)
%Remove the green cross when before updating it.
    axesChildren = get(gca, 'Children');
    %Make sure it will not remove it after update
    if removeCross
        set(axesChildren(1), 'Visible', 'Off');
    end
    
    nChildren = length(axesChildren);
    
    for idx = 1:nChildren
        try
            currentColor = get(axesChildren(idx), 'Color');
            if isequal(currentColor, [0, 1, 0]);
                set(axesChildren(idx), 'Visible', 'Off')
            end
        catch
            continue
        end
    end
    
end


function [mask_lung] = convertROItoMask(ct, ct_roi)

    l_ = 1;
    mask_lung = zeros(size(ct));
    start_slice = 1;
    end_slice = size(ct,3);
    for k_=start_slice:end_slice
        polygon_lung_original{l_} = ct_roi{k_};
        m = mask_lung(:,:,l_);
        for n = 1:length(ct_roi{k_})
            m2 = poly2mask(double(ct_roi{k_}{n}(:,1)),...
                double(ct_roi{k_}{n}(:,2)),...
                size(ct,1),...
                size(ct,2));
            m(m2) = 1;
        end
        mask_lung(:,:,l_) = m;
        l_ = l_ + 1;
    end
end
    

function inside_mask = computeThoraxInsideMask(thorax_mask)
    
    ct_thorax_bin = thorax_mask;

    % Perform several majority and erode operations to get rid of spurious
    % pixels.
    ct_thorax_bin_erode = ct_thorax_bin;
%     for k=1:size(thorax_mask,3),
%         ct_thorax_bin_erode(:,:,k) = bwmorph(ct_thorax_bin(:,:,k),'majority',2);
%         ct_thorax_bin_erode(:,:,k) = bwmorph(ct_thorax_bin_erode(:,:,k),'erode',3);
%         ct_thorax_bin_erode(:,:,k) = bwmorph(ct_thorax_bin_erode(:,:,k),'majority',2);
%     end

    % Perform 3D connected component analysis and remove the smallest
    % components
    CC = bwconncomp(ct_thorax_bin_erode,6);
    S = regionprops(CC);
    L = labelmatrix(CC);
    idx = find([S.Area]>500);
    BW = ismember(L,idx);
    %CC = bwconncomp(BW,6);
    %S = regionprops(CC);
    %L = labelmatrix(CC);

    % Compute the convex hull of the thorax and mask the inside volume.
    ct_thorax_hull = BW;
    for k=1:size(thorax_mask,3), 
        %ct_thorax_hull(:,:,k) = bwconvhull(BW(:,:,k)); 
        B = bwboundaries(BW(:,:,k),4,'noholes');
        l = length(B);
        if l>1,
            la = 1;
            for m=1:l,
                if length(B{m}) > length(B{la}),
                    la = m;
                end
            end
            B = B{la}; 
        elseif l==1,
            B = B{1}; 
        else
            continue;
        end
        ct_thorax_hull(:,:,k) = poly2mask(B(:,2),B(:,1),size(thorax_mask,1),size(thorax_mask,2));
    end
    inside_mask = ones(size(thorax_mask));
    inside_mask(find(ct_thorax_hull==0)) = 0;
end

function f = GUI_slicer(volume, isLabelMap, transparentMask, cm)
%% Beginning of outer function red_blue
% Create figure

if nargin<4,
    cm = [];
end

f = figure('Visible','on','Name','Show Slice',...
           'Position',[360,500,600,600],'resize','on','units','characters');
% Create an axes object to show which color is selected
Img = axes('Parent',f,'units','normalized',...
           'Position',[.05 .01 .85 .85]);
% Create a slider to display the images
slider1 = uicontrol('Style', 'slider', 'Parent', f, 'String', 'Image No.', 'Units', 'normalized','Callback', @slider_callback, ...
     'Position', [.05 .001 .85 .2]);

text1 = uicontrol('style','text','parent',f,'string','slice number','units','pixel','position',[50 5 100 20]);

handle.listener(slider1,'ActionEvent',@slider_callback);


movegui(Img,'onscreen')% To display application onscreen
movegui(Img,'center') % To display application in the center of screen

if isLabelMap,
    imshow(label2rgb(volume(:,:,1)));
else
    %imshow(volume(:,:,1),'displayrange',[]);
    imshow(volume(:,:,1),cm);
end

green_image = cat(3,zeros(size(volume,1)),ones(size(volume,1)), zeros(size(volume,1)));

if size(transparentMask,1)>0,
    hold on; h = imshow(green_image); hold off;
    set(h,'AlphaData',0.25*transparentMask(:,:,1));
end

set(findobj(gcf,'type','axes'),'hittest','off');
 
 set(slider1, 'Min', 1);
 set(slider1, 'Max', size(volume,3));
 set(slider1, 'value', 1);
 set(slider1, 'SliderStep', [1/size(volume,3) 1/size(volume,3)]);
 
%% Beginning of slider callback function
    function slider_callback(h, eventdata)
        currentSlice = uint32(get(slider1,'value'));
        axes(Img);
        if isLabelMap,
            imshow(label2rgb(volume(:,:,currentSlice)));
        else
            %imshow(volume(:,:,currentSlice),'displayrange',[]);
            imshow(volume(:,:,currentSlice),cm);
        end
        if size(transparentMask,1)>0,
            hold on; h = imshow(green_image); hold off;
            set(h,'AlphaData',0.25*transparentMask(:,:,currentSlice));
        end
        set(text1,'String',num2str(currentSlice));
    end
end
    

function nii = load_nii_with_rotation(filePath)
nii = load_nii(filePath);
%

mask = zeros(size(nii.img));
%
%
% % This is only necessary if there is any data in nii.img, which in this
% % setting there is not.
for k=1:size(nii.img,3),
    nii.img(:,:,k) = fliplr(imrotate(nii.img(:,:,k),90));
end
end

function tenSlicesPath = getTenSlicesPath(filePath)
allNames = regexp(filePath, filesep, 'split');
previousPath = [];



for k = 1:length(allNames) - 1
    previousPath = [previousPath filesep allNames{k}];
end
    previousPath = previousPath(2:end);
    possiblesPaths = dir([previousPath filesep '*_10Slice']);
    tenSlicesPath = [previousPath filesep possiblesPaths.name];
end



%QUANTITATIVE ANALYSIS
function quantitativeAnalysis(ct, ct_info, roi_split, exportDir, baseName)
    
    if ismac==1,
        delim = '/';
    else
        delim = '\';
    end
    
    
    
    %ct_mask = convertROItoMask(ct, ct_roi);
    ct_mask = roi_split >= 1;
    
    %roi_split = ROI_Splitter(ct, ct_mask);
    
    s_uid = ct_info{1}.SeriesInstanceUID;
    
    % Extract voxel size from DICOM header.
    ct_spacing_x = ct_info{1}.PixelSpacing(1);
    ct_spacing_y = ct_info{1}.PixelSpacing(2);
    ct_slice_thickness = ct_info{1}.SliceThickness;
    % Compute the volume of one voxel. We need it in ml for the
    % computations.
    volume_voxel = ct_spacing_x*ct_spacing_y*ct_slice_thickness;
    volume_voxel_ml = volume_voxel*0.001;
    
    header_vtotal = 1;
    header_vnon_a = 2;
    header_vnon_r = 3;
    header_vpoo_a = 4;
    header_vpoo_r = 5;
    header_vnorm_a = 6;
    header_vnorm_r = 7;
    header_vhyp_a = 8;
    header_vhyp_r = 9;
    header_gascon_a = 10;
    header_gascon_r = 11;
    header_mtotal = 12;
    header_mnon_a = 13;
    header_mnon_r = 14;
    header_mpoo_a = 15;
    header_mpoo_r = 16;
    header_mnonpo_a = 17;
    header_mnonpo_r = 18;
    header_mnorm_a = 19;
    header_mnorm_r = 20;
    header_mhyp_a = 21;
    header_mhyp_r = 22;
    
    headers = {'vtotal', 'vnon_a', 'vnon_r', 'vpoo_a', 'vpoo_r', 'vnorm_a', 'vnorm_r', 'vhyp_a', 'vhyp_r', 'gascon_a', 'gascon_r', 'mtotal', 'mnon_a', 'mnon_r', 'mpoo_a', 'mpoo_r', 'mnonpo_a', 'mnonpo_r', 'mnorm_a', 'mnorm_r', 'mhyp_a', 'mhyp_r'};

    raw = cell((size(ct,3)+2)*5+1, 22+4);
    raw(1,1:4) = {'ROI', 'Slice #', 'Slice position', 'Slice thickness'};
    raw(1,5:end) = headers;

    % Initialize table with a row for each slice and 24 columns for the 22
    % measurements + Slice Location + Slice Thickness
    for k=1:5,
        slices = zeros(size(ct,3), 22+2);
        for l=1:size(ct,3),

            ct_slice = ct(:,:,l);
            if k==5,
                voxels_lung = ct_slice(ct_mask(:,:,l)==1);
            else
                voxels_lung = ct_slice(roi_split(:,:,l)==k);
            end
            
            % Group the voxels according to their HU value.
            voxels_non  = voxels_lung(voxels_lung>=-100 & voxels_lung<=100);
            voxels_poor  = voxels_lung(voxels_lung>=-500 & voxels_lung<=-101);
            voxels_norm  = voxels_lung(voxels_lung>=-900 & voxels_lung<=-501);
            voxels_hyp  = voxels_lung(voxels_lung>=-1000 & voxels_lung<=-901);
            voxels_total = voxels_lung(voxels_lung>=-1000 & voxels_lung<=100);
            
            % Compute the volume of all voxel groups in [ml].
            volume_non = length(voxels_non) *volume_voxel_ml;
            volume_poor = length(voxels_poor) *volume_voxel_ml;
            volume_norm = length(voxels_norm) *volume_voxel_ml;
            volume_hyp = length(voxels_hyp) *volume_voxel_ml;
            volume_all = volume_non + volume_poor + volume_norm + volume_hyp;
            %volume_whole_lung = length(voxels_lung)*volume_voxel_ml;
            
            % Compute the mass of all voxel groups in [g].
            mass_all = sum((1 + 0.001*double(voxels_total))*volume_voxel_ml);
            mass_non = sum((1 + 0.001*double(voxels_non))*volume_voxel_ml);
            mass_poor = sum((1 + 0.001*double(voxels_poor))*volume_voxel_ml);
            mass_norm = sum((1 + 0.001*double(voxels_norm))*volume_voxel_ml);
            mass_hyp = sum((1 + 0.001*double(voxels_hyp))*volume_voxel_ml);
            
            % Gas content.
            gascon_r = mean(double(voxels_total)/(-1000.0));
            gascon_a = (gascon_r * volume_all);
            
            % Write the results in the table
            slices(l, header_vtotal) = volume_all;
            slices(l, header_vnon_a) = volume_non;
            %slices(l, header_vnon_r) = volume_non_r;
            slices(l, header_vpoo_a) = volume_poor;
            %slices(l, header_vpoo_r) = volume_poor_r;
            slices(l, header_vnorm_a) = volume_norm;
            %slices(l, header_vnorm_r) = volume_norm_r;
            slices(l, header_vhyp_a) = volume_hyp;
            %slices(l, header_vhyp_r) = volume_hyp_r;
            slices(l, header_gascon_a) = gascon_a;
            %slices(l, header_gascon_r) = gascon_r;
            slices(l, header_mtotal) = mass_all;
            slices(l, header_mnon_a) = mass_non;
            %slices(l, header_mnon_r) = mass_non_r;
            slices(l, header_mpoo_a) = mass_poor;
            %slices(l, header_mpoo_r) = mass_poor_r;
            slices(l, header_mnonpo_a) = mass_non + mass_poor;
            %slices(l, header_mnonpo_r) = mass_non_r + mass_poor_r;
            slices(l, header_mnorm_a) = mass_norm;
            %slices(l, header_mnorm_r) = mass_norm_r;
            slices(l, header_mhyp_a) = mass_hyp;
            %slices(l, header_mhyp_r) = mass_hyp_r;
            
            slices(l, header_mhyp_r+1) = ct_info{l}.SliceLocation;
            slices(l, header_mhyp_r+2) = ct_info{l}.SliceThickness;
        
        end
        
         % Since the ordering of the slices might be wrong, sort the rows of the
         % table by the ascending slice locations.
         sl = zeros(1,size(ct,3));
         for l=1:length(ct_info),
             sl(l)=(ct_info{l}.SliceLocation);
         end
         [~, I] = sort(sl,'ascend');
         slices = slices(I,:);
         
         % Compute the extrapolated measurements for each space between slices.
         slices_ext = zeros(size(ct,3)-1, 22);
         for l=1:size(ct,3)-1,
             d = abs(slices(l,header_mhyp_r+1)-slices(l+1,header_mhyp_r+1));
             t = slices(l,header_mhyp_r+2);
             X1 = slices(l,1:22);
             X2 = slices(l+1,1:22);
             slices_ext(l,:) = d*(X1+X2)/(2*t);
         end
         
         % Compute the final extrapolated lung measurements as the sum of all
         % extrapolated in-between values plus half of the first and half of the
         % last slice.
         lung_ext = zeros(1,22);
         for l=1:22,
             lung_ext(l) = sum(slices_ext(:,l)) + 0.5*slices_ext(1,l) + 0.5*slices_ext(end,l);
         end
         
         % Recompute all relative values with respect to v_total and m_total.
         lung_ext(header_vnon_r) = lung_ext(header_vnon_a)/lung_ext(header_vtotal)*100;
         lung_ext(header_vpoo_r) = lung_ext(header_vpoo_a)/lung_ext(header_vtotal)*100;
         lung_ext(header_vnorm_r) = lung_ext(header_vnorm_a)/lung_ext(header_vtotal)*100;
         lung_ext(header_vhyp_r) = lung_ext(header_vhyp_a)/lung_ext(header_vtotal)*100;
         lung_ext(header_mnon_r) = lung_ext(header_mnon_a)/lung_ext(header_mtotal)*100;
         lung_ext(header_mpoo_r) = lung_ext(header_mpoo_a)/lung_ext(header_mtotal)*100;
         lung_ext(header_mnonpo_r) = lung_ext(header_mnonpo_a)/lung_ext(header_mtotal)*100;
         lung_ext(header_mnorm_r) = lung_ext(header_mnorm_a)/lung_ext(header_mtotal)*100;
         lung_ext(header_mhyp_r) = lung_ext(header_mhyp_a)/lung_ext(header_mtotal)*100;
         lung_ext(header_gascon_r)=lung_ext(header_gascon_a)/lung_ext(header_vtotal)*100;
         
         
         if k==1,
             roi_name = 'RV';
         elseif k==2,
             roi_name = 'LV';
         elseif k==3,
             roi_name = 'LD';
         elseif k==4,
             roi_name = 'RD';
         elseif k==5,
             roi_name = 'All';
         else
             roi_name = '';
         end
         
         for m=1:size(ct,3),
            raw(1 + (k-1)*(size(ct,3)+2) + m, 1) = {roi_name};
            raw(1 + (k-1)*(size(ct,3)+2) + m, 2) = {m};
            raw(1 + (k-1)*(size(ct,3)+2) + m, 3) = {slices(m, 23)};
            raw(1 + (k-1)*(size(ct,3)+2) + m, 4) = {slices(m, 24)};
            for n = 1:22,
                raw(1 + (k-1)*(size(ct,3)+2) + m, 4+n) = {slices(m, n)};
            end
         end
         
         raw(1 + (k-1)*(size(ct,3)+2) + size(ct,3)+1, 2) = {'% ROI'};
         raw(1 + (k-1)*(size(ct,3)+2) + size(ct,3)+2, 2) = {'% Lung'};
         
         for n=1:22,
             raw(1 + (k-1)*(size(ct,3)+2) + size(ct,3)+1, 4+n) = {lung_ext(n)};
             raw(1 + (k-1)*(size(ct,3)+2) + size(ct,3)+2, 4+n) = {lung_ext(n)};
         end
    end
    
    for k=1:4,
       
        lung_ext_new = zeros(size(lung_ext));
        for n=1:22,
           lung_ext_new(n) = raw{1 + (k-1)*(size(ct,3)+2) + size(ct,3) + 1, 4+n}; 
        end
        % Recompute all relative values with respect to v_total and m_total.
        lung_ext_new(header_vnon_r) = lung_ext_new(header_vnon_a)/lung_ext(header_vtotal)*100;
        lung_ext_new(header_vpoo_r) = lung_ext_new(header_vpoo_a)/lung_ext(header_vtotal)*100;
        lung_ext_new(header_vnorm_r) = lung_ext_new(header_vnorm_a)/lung_ext(header_vtotal)*100;
        lung_ext_new(header_vhyp_r) = lung_ext_new(header_vhyp_a)/lung_ext(header_vtotal)*100;
        lung_ext_new(header_mnon_r) = lung_ext_new(header_mnon_a)/lung_ext(header_mtotal)*100;
        lung_ext_new(header_mpoo_r) = lung_ext_new(header_mpoo_a)/lung_ext(header_mtotal)*100;
        lung_ext_new(header_mnonpo_r) = lung_ext_new(header_mnonpo_a)/lung_ext(header_mtotal)*100;
        lung_ext_new(header_mnorm_r) = lung_ext_new(header_mnorm_a)/lung_ext(header_mtotal)*100;
        lung_ext_new(header_mhyp_r) = lung_ext_new(header_mhyp_a)/lung_ext(header_mtotal)*100;
        lung_ext_new(header_gascon_r)=lung_ext_new(header_gascon_a)/lung_ext(header_vtotal)*100;
        
        for n=1:22,
             raw(1 + (k-1)*(size(ct,3)+2) + size(ct,3)+2, 4+n) = {lung_ext_new(n)};
         end
        
    end
    
%     folder_name = textscan(fn,'%s','delimiter',delim);
%     folder_name = folder_name{:};
%     folder_name = folder_name(end);
%     folder_name = folder_name{:};
%     
%     ct_info = ct_info{1};
%     


xlwrite([exportDir filesep baseName '.xls'], raw);
msgbox('Results Successfully saved', 'Results saved')
     
%    %save(strcat(fn,delim,folder_name,'_roi_split.mat'), 's_uid', 'roi_split', 'ct_info');

end

