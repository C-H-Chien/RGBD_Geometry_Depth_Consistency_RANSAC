function Times = est_rel_pose_classic( PARAMS, all_pointsRGB_v1, all_pointsRGB_v2, K, R12, T12, ...
                                       all_points2D_v1, all_points2D_v2, ...
                                       all_points3D_v1, all_points3D_v2)
    
    Times.profile_time1 = 0;
    Times.profile_time2 = 0;
    Times.profile_time3 = 0;
    
    Times.profile_pick_rand_permutation = 0;
    Times.profile_access_RGB_data = 0;
    
    Times.profile_true_matches_num = 0;
    Times.profile_pass_geom_constraint_num = 0;
    Times.profile_pass_photo_constraint_num = 0;
    Times.profile_pass_combined_conostraint_num = 0;
    
    Times.Min_Iterations = 0;
    Times.orientation_err_deg_when_success = 0;
    Times.transl_err_when_success = 0;
    Times.max_inlier_ratio_for_accurate_pose_when_success = 0;
    Times.success_flag = 0;
    
    if PARAMS.DO_TIME_PROFILING == 1
        profiling_repetition = 1000;
    else
        profiling_repetition = 1;
    end
    
    if PARAMS.TOP_RANK_ORDERED_LIST_SIZE > size(all_points3D_v1, 1)
        num_of_matches = size(all_points3D_v1, 1);
    else
        num_of_matches = PARAMS.TOP_RANK_ORDERED_LIST_SIZE;
    end
    
    max_count = 0;
    flag = 1;
    Times.Min_Iterations = PARAMS.NUM_OF_CLASSIC_RANSAC_ITERATIONS;
    for iter = 1:PARAMS.NUM_OF_CLASSIC_RANSAC_ITERATIONS
        
        %> Profiling 1: Pick 3 random points from the rank-ordered list and
        %  also access their data
        tic;
        for ti = 1:profiling_repetition
            ind  = randperm(num_of_matches, 3);
            id1 = ind(1);
            id2 = ind(2);
            id3 = ind(3);
            
            xyz1  = all_points3D_v1(id1, :);
            xyz1_ = all_points3D_v2(id1, :);
            xyz2  = all_points3D_v1(id2, :);
            xyz2_ = all_points3D_v2(id2, :);
            xyz3  = all_points3D_v1(id3, :);
            xyz3_ = all_points3D_v2(id3, :);
            
            pt1_2d  = all_points2D_v1(id1, :);
            pt1_2d_ = all_points2D_v2(id1, :);
            pt2_2d  = all_points2D_v1(id2, :);
            pt2_2d_ = all_points2D_v2(id2, :);
            pt3_2d  = all_points2D_v1(id3, :);
            pt3_2d_ = all_points2D_v2(id3, :);
        end
        time_ = toc;
        Times.profile_time1 = Times.profile_time1 + (time_/1000);
        
        tic;
        for ti = 1:profiling_repetition
            rgb1  = all_pointsRGB_v1(id1, :);
            rgb1_ = all_pointsRGB_v2(id1, :);            
            rgb2  = all_pointsRGB_v1(id2, :);
            rgb2_ = all_pointsRGB_v2(id2, :);
            rgb3  = all_pointsRGB_v1(id3, :);
            rgb3_ = all_pointsRGB_v2(id3, :);
        end
        time_ = toc;
        Times.profile_access_RGB_data = Times.profile_access_RGB_data + (time_/1000);
        
        distance1  = norm(xyz1  - xyz2);
        distance1_ = norm(xyz1_ - xyz2_);
        distance2  = norm(xyz1  - xyz3);
        distance2_ = norm(xyz1_ - xyz3_);
        distance3  = norm(xyz2  - xyz3);
        distance3_ = norm(xyz2_ - xyz3_);
        err1_geom = abs(distance1-distance1_);
        err2_geom = abs(distance2-distance2_);
        err3_geom = abs(distance3-distance3_);
        
        err1_photo = norm(rgb1(:) - rgb1_(:));
        err2_photo = norm(rgb2(:) - rgb2_(:));
        err3_photo = norm(rgb3(:) - rgb3_(:));
        
        %> Compute the reprojection errors to see how many loops we need to get very good 3 pairs
        transformed_xyz1 = K * (R12 * xyz1' + T12);
        projected_pt = transformed_xyz1 ./ transformed_xyz1(3,1);
        reprojection_error_pt1 = norm(pt1_2d_' - projected_pt(1:2, 1));
        
        transformed_xyz2 = K * (R12 * xyz2' + T12);
        projected_pt = transformed_xyz2 ./ transformed_xyz2(3,1);
        reprojection_error_pt2 = norm(pt2_2d_' - projected_pt(1:2, 1));
        
        transformed_xyz3 = K * (R12 * xyz3' + T12);
        projected_pt = transformed_xyz3 ./ transformed_xyz3(3,1);
        reprojection_error_pt3 = norm(pt3_2d_' - projected_pt(1:2, 1));
        
        if reprojection_error_pt1 < 2 && reprojection_error_pt2 < 2 && reprojection_error_pt3 < 2
            Times.profile_true_matches_num = Times.profile_true_matches_num + 1;
            
            %>>> Measure the percentage of passing geometric constraint
            if err1_geom < PARAMS.GEOMETRY_ERR_THRESH && ...
               err2_geom < PARAMS.GEOMETRY_ERR_THRESH && ...
               err3_geom < PARAMS.GEOMETRY_ERR_THRESH
                Times.profile_pass_geom_constraint_num = Times.profile_pass_geom_constraint_num + 1;
            else
                
            end

            %>>> Measure the percentage of passing photometric constraint
            if err1_photo < PARAMS.PHOTOMETRIC_ERR_THRESH && ...
               err2_photo < PARAMS.PHOTOMETRIC_ERR_THRESH && ...
               err3_photo < PARAMS.PHOTOMETRIC_ERR_THRESH
                Times.profile_pass_photo_constraint_num = Times.profile_pass_photo_constraint_num + 1;
            end
            
            if err1_geom < PARAMS.GEOMETRY_ERR_THRESH && ...
               err2_geom < PARAMS.GEOMETRY_ERR_THRESH && ...
               err3_geom < PARAMS.GEOMETRY_ERR_THRESH && ...
               err1_photo < PARAMS.PHOTOMETRIC_ERR_THRESH && ...
               err2_photo < PARAMS.PHOTOMETRIC_ERR_THRESH && ...
               err3_photo < PARAMS.PHOTOMETRIC_ERR_THRESH
                Times.profile_pass_combined_conostraint_num = Times.profile_pass_combined_conostraint_num + 1;
            end
        end
        
%         if flag == 1 && reprojection_error_pt1 < 1.5 && reprojection_error_pt2 < 1.5 && reprojection_error_pt3 < 1.5
%             Times.Min_Iterations = iter;
%             flag = 0;
%             %break;
%         end
        
        points3D_set1 = [xyz1; xyz2; xyz3];
        points3D_set2 = [xyz1_; xyz2_; xyz3_];
        [R_, t_] = align_point_clouds(points3D_set2, points3D_set1);
        %time_ = toc;
        %Times.profile_time6 = Times.profile_time6 + time_;

        %> Profiling 7: find final solution corresponds to maximal inliers
        %> TODO: use Sampson error???
        %tic;
        [inlier_count, ~] = compute_alignment_rmse(all_points3D_v1, all_points3D_v2, R_, t_);
        
        %> 1) If pose estimation is very accurate, what is the max inlier ratio
        R = R_;
        T = t_;
        %> Angular error for rotation matrix
        orientation_err_rad = abs(acos((trace(R'*R12)-1)/2));
        orientation_err_deg = rad2deg(orientation_err_rad);

        %> Translation error
        transl_err = norm(T - T12);
        
        if flag == 1 && transl_err < PARAMS.TRANSLATION_DIST_TOL && ...
           orientation_err_deg < PARAMS.ORIENTATION_DEG_TOL
            Times.Min_Iterations = iter;
            Times.orientation_err_deg_when_success = orientation_err_deg;
            Times.transl_err_when_success = transl_err;
            Times.max_inlier_ratio_for_accurate_pose_when_success = inlier_count / size(all_points3D_v1, 1);
            Times.success_flag = 1;
            flag = 0;
        end
        
        %> 2) For max inlier ratio, how accurate is the pose estimation
        %> This statement will always be entered...
        if max_count <= inlier_count
            max_count = inlier_count;
            Times.orientation_err_deg = orientation_err_deg;
            Times.transl_err = transl_err;
            Times.max_inlier_ratio_for_accurate_pose = max_count / size(all_points3D_v1, 1);
        end
    end
    
    Times.success = 1 - flag;
end

function transformed_points = transform_point_cloud(points, R, t)
    % Transforms a point cloud using a rotation matrix and translation vector
    %
    % Inputs:
    %   points: Nx3 matrix of 3D points to be transformed
    %   R: 3x3 rotation matrix
    %   t: 3x1 translation vector
    %
    % Outputs:
    %   transformed_points: Nx3 matrix of transformed 3D points

    % Apply the rotation matrix and translation vector to the points
    transformed_points = (R * points')' + t';

end


function [inlier_count,rmse_error] = compute_alignment_rmse(point_cloud2, point_cloud1, R, t)
    % Computes the root-mean-square error (RMSE) between two point clouds after alignment
    %
    % Inputs:
    %   point_cloud1: Nx3 matrix of 3D points in the first point cloud
    %   point_cloud2: Mx3 matrix of 3D points in the second point cloud
    %   R: 3x3 rotation matrix to align point_cloud2 with point_cloud1
    %   t: 3x1 translation vector to align point_cloud2 with point_cloud1
    %
    % Outputs:
    %   rmse_error: scalar value of the RMSE between the two aligned point clouds

    % Transform point_cloud2 to align with point_cloud1
    transformed_point_cloud2 = transform_point_cloud(point_cloud2, R, t);
    size(transformed_point_cloud2);

    % Compute the distances between each corresponding point in the two point clouds
    distances = sqrt(sum((point_cloud1 - transformed_point_cloud2).^2, 2));

    inlier_count=sum(distances<0.01);
    % Compute the root-mean-square error between the two point clouds
    rmse_error = sqrt(mean(distances.^2));
end