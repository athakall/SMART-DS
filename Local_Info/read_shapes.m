clc
clearvars
dbstop if error
addpath(genpath(fullfile('C:\SMART-DS')));
dataFolder='C:\Dropbox (MIT)\SMART_DS\data\cities\medium_CA';
d=10; % distance between the auxiliary consumers for the street map
pf=0.8; % inductive power factor of all the loads
LV=0.416;
MV=11;

%% Load roads data and convert to meters
roads_deg=shaperead(fullfile(dataFolder,'demo2r.shp'));
roadSegs.x=[];
roadSegs.y=[];
nRoads=length(roads_deg);
nSubRoads=zeros(nRoads,1);
for i=1:nRoads
    nanLocs=find(isnan(roads_deg(i).X ));
    for j=1:length(nanLocs)
        if j==1
            subRoadLon=roads_deg(i).X(1:nanLocs(1)-1);
            subRoadLat=roads_deg(i).Y(1:nanLocs(1)-1);            
        else
            subRoadLon=roads_deg(i).X(nanLocs(j-1)+1:nanLocs(j)-1);
            subRoadLat=roads_deg(i).Y(nanLocs(j-1)+1:nanLocs(j)-1);
        end
        [subRoadX,subRoadY,~]=deg2utm(subRoadLat,subRoadLon);
        roadSegs.x=[roadSegs.x;[subRoadX(1:end-1),subRoadX(2:end)]];
        roadSegs.y=[roadSegs.y;[subRoadY(1:end-1),subRoadY(2:end)]];
    end
    nSubRoads(i)=j;
end

%% Virtual users for the creation of the roadmap
mapUsers.x=roadSegs.x(:,1);
mapUsers.y=roadSegs.y(:,1);

nRoadSegs=length(roadSegs.x);

for i=1:nRoadSegs
   segLength(i)=sqrt((roadSegs.x(i,2)-roadSegs.x(i,1))^2+...
       (roadSegs.y(i,2)-roadSegs.y(i,1))^2);
   segSlope(i)= (roadSegs.y(i,2)-roadSegs.y(i,1))/...
       (roadSegs.x(i,2)-roadSegs.x(i,1));
   nSegPoints(i)= max(0,floor(segLength(i)/d)-1);
   xPoints=roadSegs.x(i,1)+((roadSegs.x(i,2)-roadSegs.x(i,1))/(nSegPoints(i)+1)*...
       linspace(1,nSegPoints(i),nSegPoints(i)));
   yPoints=roadSegs.y(i,1)+segSlope(i)*(xPoints-roadSegs.x(i,1));
   mapUsers.x=[mapUsers.x;xPoints'];
   mapUsers.y=[mapUsers.y;yPoints'];
end

nMapUsers=length(mapUsers.x);

%% Load buildings data, convert to meters and calculate the shape centroids
% I'm using the centroid of the bounding box for now.
buildings_deg=shaperead(fullfile(dataFolder,'demo2b.shp'));
nBuildings=length(buildings_deg);
centerLat=nan(nBuildings,1);
centerLon=nan(nBuildings,1);
buildingArea=nan(nBuildings,1);
nSubBuildings=nan(nBuildings,1);
for i=1:nBuildings
    
    %% Center of the bounding box in degrees
    centerLon(i)=mean(buildings_deg(i).BoundingBox(:,1));
    centerLat(i)=mean(buildings_deg(i).BoundingBox(:,2));
    bVertex.x=[];
    bVertex.y=[];
        
    %% Area of each building and best connection vertex
    nanLocs=find(isnan(buildings_deg(i).X));
    buildingArea(i)=0;
    for j=1:length(nanLocs)
        if j==1
            polyLat=buildings_deg(i).Y(1:nanLocs(j)-1);
            polyLon=buildings_deg(i).X(1:nanLocs(j)-1); 
           
        else
            polyLat=buildings_deg(i).Y(nanLocs(j-1)+1:nanLocs(j)-1);
            polyLon=buildings_deg(i).X(nanLocs(j-1)+1:nanLocs(j)-1);
            
        end
        [polyX,polyY,~]=deg2utm(polyLat,polyLon); 
        bVertex.x=[bVertex.x;polyX];
        bVertex.y=[bVertex.y;polyY];
        buildingArea(i)=buildingArea(i)+polyarea(polyX,polyY);
    end
    nSubBuildings(i)=j;  
    M1x=repmat(bVertex.x,1,nMapUsers);
    M1y=repmat(bVertex.y,1,nMapUsers);
    
    M2x=repmat(mapUsers.x',length(bVertex.x),1);
    M2y=repmat(mapUsers.y',length(bVertex.x),1);
    
    dx=M1x-M2x;
    dy=M1y-M2y;
    d=sqrt(dx.^2+dy.^2);
    [M,I] = min(d(:));
    [I_row, I_col] = ind2sub(size(d),I);
    users.x(i,1)=bVertex.x(I_row);
    users.y(i,1)=bVertex.y(I_row);
    
    if mod(i,10)
        clc
        disp([num2str(i) ' buildings processed']);
    end
   
    
end

[userCentroid.x,userCentroid.y,~]=deg2utm(centerLat,centerLon);

%% Find the best supply point
% I'm considering the vertex of the building's polygon which is closest to
% a streetmap node

%% Compile other fields

users.z=zeros(nBuildings,1);
users.p=round(50*buildingArea/1000,2); % peak power in kW
users.q=users.p*tan(acos(pf));
users.v=LV*ones(nBuildings,1); % default to LV
users.v(users.p>50)=MV; % if the load is greater than 50 kW peak, move to MV
users.nPhases=ones(nBuildings,1); % default to single phase
users.nPhases(users.v==0.4 & users.p>20)=3; % Move LV users of more than 20 kW peak to 3 phase
users.nPhases(users.p>200)=3; % Move all users of more than 200 kW peak to 3 phase

%% write user codes
nLV=0;
nMV=0;
users.id={};
for i=1:nBuildings
    if users.v(i)==LV
        nLV=nLV+1;
    users.id{i,1}=['CLV' num2str(nLV)];
    elseif users.v(i)==MV
        nMV=nMV+1;
        users.id{i}=['CMV' num2str(nMV)];
    end        
end

nMapUsers=length(mapUsers.x);
for i=1:nMapUsers
    mapUsers.id{i,1}=['SM' num2str(i)];
end
mapUsers.z=zeros(nMapUsers,1);

%% write files
users.x=round(users.x,1);
users.y=round(users.y,1);
tUsers=table(users.x,users.y,users.z,users.id,users.v,users.p,users.q,users.nPhases);
writetable(tUsers,fullfile(dataFolder,'customers.txt'),'Delimiter',';','writeVariableNames',false);

mapUsers.x=round(mapUsers.x,1);
mapUsers.y=round(mapUsers.y,1);
tMapUsers=table(mapUsers.x,mapUsers.y,mapUsers.z,mapUsers.id);
writetable(tMapUsers,fullfile(dataFolder,'PointStreetMap.txt'),'Delimiter',';','writeVariableNames',false);

%% Show roads and buildings
% close all
% figure(1)
% mapshow(roads_deg)
% mapshow(buildings_deg)
% %%
% figure(2)
%  line(roadSegs.x',roadSegs.y','Color','black')
%  hold on
%  scatter(users.x,users.y,5,'red','filled')
%  scatter(mapUsers.x,mapUsers.y,6,'blue','filled');
%  hold off

