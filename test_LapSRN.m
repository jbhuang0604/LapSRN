function test_LapSRN(model_scale, depth, gpu, dataset, test_scale, epoch)
% -------------------------------------------------------------------------
%   Description:
%       Script to test LapSRN on benchmark datasets
%       Compute PSNR, SSIM and IFC
%
%   Input:
%       - model_scale   : model SR scale
%       - depth         : model depth
%       - gpu           : GPU ID
%       - dataset       : testing dataset (Set5, Set14, BSDS100, urban100, manga109)
%       - test_scale    : testing SR scale (could be different from model scale)
%       - epoch         : model epoch to test
%
%   Citation: 
%       Deep Laplacian Pyramid Networks for Fast and Accurate Super-Resolution
%       Wei-Sheng Lai, Jia-Bin Huang, Narendra Ahuja, and Ming-Hsuan Yang
%       IEEE Conference on Computer Vision and Pattern Recognition (CVPR), 2017
%
%   Contact:
%       Wei-Sheng Lai
%       wlai24@ucmerced.edu
%       University of California, Merced
% -------------------------------------------------------------------------
    
    if( test_scale < model_scale )
        error('Test scale must be greater than or equal to model scale (%d vs %d)', ...
            test_scale, model_scale);
    end

    %% generate opts
    opts = init_opts(model_scale, depth, gpu);
    
    %% setup paths
    addpath(genpath('utils'));
    addpath(fullfile(pwd, 'matconvnet/matlab'));
    vl_setupnn;
    
    input_dir = fullfile('datasets', dataset, 'GT');
    output_dir = fullfile(opts.train.expDir, sprintf('epoch_%d', epoch), ...
                          dataset, sprintf('x%d', test_scale));

    if( ~exist(output_dir, 'dir') )
        mkdir(output_dir);
    end
    
    %% Load model
    model_filename = fullfile(opts.train.expDir, sprintf('net-epoch-%d.mat', epoch));
    fprintf('Load %s\n', model_filename);
    
    net = load(model_filename);
    net = dagnn.DagNN.loadobj(net.net);
    net.mode = 'test' ;

    output_var = 'level1_output';
    output_index = net.getVarIndex(output_var);
    net.vars(output_index).precious = 1;

    if( opts.gpu )
        gpuDevice(opts.gpu)
        net.move('gpu');
    end

    %% load image list
    list_filename = sprintf('lists/%s.txt', dataset);
    img_list = load_list(list_filename);
    num_img = length(img_list);
    

    %% testing
    PSNR = zeros(num_img, 1);
    SSIM = zeros(num_img, 1);
    IFC  = zeros(num_img, 1);
    
    for i = 1:num_img
        
        img_name = img_list{i};
        fprintf('Process %s %d/%d: %s\n', dataset, i, num_img, img_name);
        
        % Load HR image
        input_filename = fullfile(input_dir, sprintf('%s.png', img_name));
        img_GT = im2double(imread(input_filename));
        img_GT = mod_crop(img_GT, test_scale);
    
        % generate LR image
        img_LR = imresize(img_GT, 1/test_scale, 'bicubic');
            
        % apply LapSRN
        img_HR = SR_LapSRN(img_LR, net, opts);
            
        % save result
        output_filename = fullfile(output_dir, sprintf('%s.png', img_name));
        fprintf('Save %s\n', output_filename);
        imwrite(img_HR, output_filename);

        %% evaluate
        img_HR = im2double(im2uint8(img_HR)); % quantize pixel values
        
        % convert to gray scale
        img_GT = rgb2ycbcr(img_GT); img_GT = img_GT(:, :, 1);
        img_HR = rgb2ycbcr(img_HR); img_HR = img_HR(:, :, 1);
        
        % crop boundary
        img_GT = shave_bd(img_GT, test_scale);
        img_HR = shave_bd(img_HR, test_scale);
        
        % evaluate
        PSNR(i) = psnr(img_GT, img_HR);
        SSIM(i) = ssim(img_GT, img_HR);
        
        % comment IFC to speed up testing
%         IFC(i) = ifcvec(img_GT, img_HR);
%         if( ~isreal(IFC(i)) )
%             IFC(i) = 0;
%         end

    end
    
    PSNR(end+1) = mean(PSNR);
    SSIM(end+1) = mean(SSIM);
    IFC(end+1)  = mean(IFC);
    
    fprintf('Average PSNR = %f\n', PSNR(end));
    fprintf('Average SSIM = %f\n', SSIM(end));
    fprintf('Average IFC = %f\n', IFC(end));
    
    filename = fullfile(output_dir, 'PSNR.txt');
    save_matrix(PSNR, filename);

    filename = fullfile(output_dir, 'SSIM.txt');
    save_matrix(SSIM, filename);
    
    filename = fullfile(output_dir, 'IFC.txt');
    save_matrix(IFC, filename);
