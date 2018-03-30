function ais_2km_jigsaw()
% 2km ais mesh

    name = 'ais2km';

    addpath('dual-mesh');

%------------------------------------ setup files for JIGSAW

    opts.geom_file = ...                % GEOM file
    [name '-GEOM.msh'];
    
    opts.jcfg_file = ...                % JCFG file
    [name '.jig'];
    
    opts.mesh_file = ...                % MESH file
    [name '-MESH.msh'];
    
    opts.hfun_file = ...                % HFUN file
    [name '-HFUN.msh'];
    
%------------------------------------ define JIGSAW geometry

    geom.mshID = 'EUCLIDEAN-MESH';

    x0=-3.0e6; x1=3.0e6;
    y0=-2.5e6; y1=2.5e6;
    geom.point.coord = [    % list of xy "node" coordinates
        x0, y0, 0
        x1, y0, 0
        x1, y1, 0
        x0, y1, 0 ] ;
    
    geom.edge2.index = [    % list of "edges" between nodes
        1, 2, 0
        2, 3, 0
        3, 4, 0
        4, 1, 0  ] ;    
        
    savemsh(opts.geom_file, geom) ;
    
%------------------------------------ compute HFUN over GEOM
        
%%
% densFile='density.nc';
% xpos=ncread(densFile, 'x');
% ypos=ncread(densFile, 'y');
% dens = ncread(densFile, 'density')';
% hfun = dens.^-0.25*1000.0 * 10.0;
% 
% 
% 
% 
%    [XPOS,YPOS] = meshgrid(xpos,ypos) ;
%     
% 
%     hmat.mshID = 'EUCLIDEAN-GRID' ;
%     hmat.point.coord{1} = xpos ;
%     hmat.point.coord{2} = ypos ;
%     hmat.value = hfun ;
% 
%         
%     savemsh(opts.hfun_file,hmat) ;

    
%% calculate density based on new criteria

%% load AIS data file

aisFile = '/Users/mhoffman/documents/antarctica_data/piscees_complete/antarctica_8km_2014_01_14.nc';
x1=ncread(aisFile, 'x1');
y1=ncread(aisFile, 'y1');
thk = ncread(aisFile, 'thk')';
topg = ncread(aisFile, 'topg')';

dx = x1(2)-x1(1);
nx = length(x1);
ny = length(y1);
    
   
%% calculate mask of marine-based bed areas that are connected to the ocean

marineElevationWAIS = -300.0;  % elevation to consider marine bed
marineElevationEAIS = -300.0;  % elevation to consider marine bed


% initialize mask
maskSize = size(thk);
marineMask = zeros(maskSize, 'int8');
marineMask(2,2:end-1) = 1;
marineMask(end-1,2:end-1) = 1;
marineMask(2:end-1,2) = 1;
marineMask(2:end-1,end-1) = 1;

lastSearchList = find(marineMask==1);  % indices  searched last iteration

marineMask(1,:) = 1;
marineMask(end,:) = 1;
marineMask(:,1) = 1;
marineMask(:,end) = 1;

searchedMask = marineMask;



neighbors=[[1,0]; [-1,0]; [0,1]; [0,-1]]';

% flood fill with elevation threshold
while (length(lastSearchList) > 0)
    newSearchList = [];

    for iii=1:length(lastSearchList);
        [i, j] = ind2sub(maskSize, lastSearchList(iii));
        % search neighbors
        for n=neighbors;
            %n
            ii=i+n(1); jj=j+n(2);  % subscripts to neighbor          
            if searchedMask(ii,jj) == 0;  % only consider unsearched neighbors
                searchedMask(ii,jj) = 1;  % mark as searched
                if x1(j) > -500.0e3
                    marineElevation = marineElevationEAIS;
                else
                    marineElevation = marineElevationWAIS;
                end                    

                if (topg(ii, jj) < marineElevationWAIS & x1(j) < -500.0e3 ) | ...
                        (topg(ii, jj) < marineElevationEAIS & x1(j) > -500.0e3 & thk(ii,jj)<2500.0 ) | ...
                        (thk(ii,jj) ==0.0);  % check if this location is below the elevation threshold OR there is no ice here.
                    marineMask(ii,jj) = 1;  % mark as marine
                    newSearchList = [newSearchList, sub2ind(maskSize, ii, jj)];  % add to list of newly found marine cells
                end
            end % if unsearched
        end % 4 neighbors
    end % one of found locations last time
    lastSearchList = newSearchList;
end


figure(99); clf; hold all
pcolor(marineMask)
shading flat
colorbar
axis equal



%% make mask of 'grounding line'
neighbors=[[1,0]; [-1,0]; [0,1]; [0,-1];   [1,1]; [-1,-1]; [-1,1]; [1,-1]]';

groundedNeighborMask = marineMask*0;
for n=neighbors;
   groundedNeighborMask = groundedNeighborMask | ~(circshift(marineMask, n));
end
GLmask = marineMask & groundedNeighborMask;


% ice front mask
marginMask = marineMask*0;
iceMask = thk>0;
for n=neighbors;
   marginMask = marginMask | ~(circshift(iceMask, n));
end
marginMask = marginMask & iceMask;

% add in ice margin to the "GL" mask
GLmask = GLmask | marginMask;



GLind = find(GLmask==1);
nGL = length(GLind);

figure(98); clf; hold all
pcolor(GLmask)
shading flat
colorbar
axis equal


[YPOS,XPOS] = meshgrid(x1,y1);

%% calculate distance to marine-based bed
distToMarine = thk*0.0;

d=80;
rng = [-1*d:d];
maxdist = d * dx

ind = find( (marineMask==0) | (thk<(-1028/910*topg)));  % just look over non-marine areas
for iii=1:length(ind);
    [i, j] = ind2sub(maskSize, ind(iii));
    

    irng = i+rng;
    jrng = j+rng;
    
    irng = irng(find(irng>0 & irng < nx));
    jrng = jrng(find(jrng>0 & jrng < ny));
        
    dist2Here = ((XPOS(irng,jrng)-x1(i)).^2 + (YPOS(irng,jrng)-y1(j)).^2).^0.5;
    dist2Here(GLmask(irng,jrng)==0) = maxdist;
    distToMarine(i,j) = min(dist2Here(:));
%     minDist = 1.0e12;
%     for g = 1:nGL;
%         [ii,jj] = ind2sub(maskSize, GLind(g));
%         dist = sqrt((ii-i)^2 + (jj-j)^2) * dx;
%         minDist = min(minDist, dist);
%     end
%     distToMarine(i,j) = minDist;
end


figure(97); clf; hold all
pcolor(distToMarine/1000.0)
shading flat
colorbar
axis equal

%% make spacing a fn of distance to GL

    groundedMask = (thk > -1028.0/910.0 * topg);
    floatingMask = ~groundedMask & thk>0.0;

    
    minSpacing = 10.0e3;
    maxSpacing = 100.0e3;
    
    minDist = 0.0;
    maxDist = 400.0e3;
    
    % linear
    m = (maxSpacing-minSpacing) / (maxDist-minDist) 
    b = minSpacing - m * minDist;
    hfun = m * distToMarine + b;
    
    hfun = (m * groundedMask + 0.5 * m * ~groundedMask) .* distToMarine + b;

%     % power law  (e.g. doubling every 100 km)
%     hfun = minSpacing * 2.^(distToMarine/100.0e3);


     hfun(hfun<minSpacing) = minSpacing;
     hfun(hfun>maxSpacing) = maxSpacing;
     hfun(hfun>3.0*minSpacing & floatingMask) = 3.0*minSpacing;

    hmat.value = hfun ;

   
    
figure(96); clf; hold all
pcolor(hfun/1000.0)
shading flat
colorbar
axis equal


%% save to jigsaw format        

    hmat.mshID = 'EUCLIDEAN-GRID' ;
    hmat.point.coord{1} = x1 ;
    hmat.point.coord{2} = y1 ;
    hmat.value = hfun ;


    savemsh(opts.hfun_file,hmat) ;


%% ------------------------------------ build mesh via JIGSAW! 
  
    opts.hfun_scal = 'absolute';
    opts.hfun_hmax = +inf ;             % null HFUN limits
    opts.hfun_hmin = 0.00 ;
  
    opts.mesh_dims = +2 ;               % 2-dim. simplexes
    
    opts.optm_qlim = 0.9375 ;
   
    opts.mesh_top1 = true ;             % for sharp feat's
    opts.geom_feat = true ;
    
    mesh = jigsaw  (opts) ;
 
%------------------------------------ draw mesh/cost outputs

    ang2 = triang2( ...                 % calc. tri-angles
        mesh.point.coord(:,1:2), ...
        mesh.tria3.index(:,1:3)) ;
            
    t_90 = max(ang2,[],2) > 90.0 ;
    t_95 = max(ang2,[],2) > 95.0 ;
    
    figure(1); clf;
    patch ('faces',geom.edge2.index(:,1:2), ...
        'vertices',geom.point.coord(:,1:2), ...
        'facecolor','w', ...
        'edgecolor',[.1,.1,.1], ...
        'linewidth',1.5) ;
    hold on; axis image;
    title('JIGSAW GEOM data') ;

    figure(2); clf; hold all;
    pcolor(XPOS,YPOS,hmat.value);
    axis equal; 
    shading interp ;
    title('JIGSAW HFUN data') ;
        patch ('faces',geom.edge2.index(:,1:2), ...
        'vertices',geom.point.coord(:,1:2), ...
        'facecolor','w', ...
        'edgecolor',[1,.1,.1], ...
        'linewidth',1.5) ;
    colorbar();


    figure(3); clf;
    patch ('faces',mesh.tria3.index(:,1:3), ...
        'vertices',mesh.point.coord(:,1:2), ...
        'facecolor','w', ...
        'edgecolor',[.2,.2,.2]) ;
    hold on; axis image;
    patch ('faces',mesh.tria3.index(t_90,1:3), ...
        'vertices',mesh.point.coord(:,1:2), ...
        'facecolor','y', ...
        'edgecolor',[.2,.2,.2]) ;
    patch ('faces',mesh.tria3.index(t_95,1:3), ...
        'vertices',mesh.point.coord(:,1:2), ...
        'facecolor','r', ...
        'edgecolor',[.2,.2,.2]) ;
    patch ('faces',mesh.edge2.index(:,1:2), ...
        'vertices',mesh.point.coord(:,1:2), ...
        'facecolor','w', ...
        'edgecolor',[.1,.1,.1], ...
        'linewidth',1.5) ;
    axis equal
    title('JIGSAW TRIA mesh') ;

    drawscr(mesh.point.coord (:,1:2), ...
            mesh.edge2.index (:,1:2), ...
            mesh.tria3.index (:,1:3)) ;
    
    drawnow ;        
%     set(figure(1),'units','normalized', ...
%         'position',[.05,.55,.30,.35]) ;
%     set(figure(2),'units','normalized', ...
%         'position',[.35,.55,.30,.35]) ;
%     set(figure(3),'units','normalized', ...
%         'position',[.35,.10,.30,.35]) ;
%     set(figure(4),'units','normalized', ...
%         'position',[.05,.10,.30,.35]) ;
    drawnow ;

end
function d = point_to_line(pt, v1, v2)

%       a = v1 - v2;
%       b = pt - v2;
%       d = norm(cross([a(1), a(2), 0], [b(1), b(2), 0])) / norm(a);
       
m=(v2(2)-v1(2))/(v2(1)-v1(1));
b=v1(2)-m*v1(1);
d=abs(m*pt(1) + -1*pt(2) + b)/sqrt(m^2+(-1)^2);

%       
% a=v1; b=v2; x=pt;
% d_ab = norm(a-b);
% d_ax = norm(a-x);
% d_bx = norm(b-x);
% 
% if dot(a-b,x-b)*dot(b-a,x-a)>=0
%     A = [a,1;b,1;x,1];
%     dist = abs(det(A))/d_ab;        
% else
%     dist = min(d_ax, d_bx);
% end      
%     d=dist;  
    
end