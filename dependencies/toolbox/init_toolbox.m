function [] = init_toolbox(base_path)
    addpath(strcat(base_path,'/channels'));
    addpath(strcat(base_path,'/classify'));
    addpath(strcat(base_path,'/detector'));
    addpath(strcat(base_path,'/external'));
    addpath(strcat(base_path,'/filters'));
    addpath(strcat(base_path,'/images'));
    addpath(strcat(base_path,'/matlab'));
    addpath(strcat(base_path,'/videos'));
end
