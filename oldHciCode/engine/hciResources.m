classdef hciResources < hgsetget
    properties
        icons
        colors
        images
    end
    methods
        function self = hciResources(varargin)
            self = prtUtilAssignStringValuePairs(self,varargin{:});
            
            init(self)
        end
        function init(self)
            initIcons(self);
           
            initColors(self);
            initImages(self);
        end
        function initIcons(self)
            self.icons = hciUtilLoadIcons;
        end
        function initColors(self)
            self.colors = hciUtilResourceColors;
        end
        function initImages(self)
            imageDir = fullfile(hciRoot,'dependencies','images');
            self.images.mouse = imread(fullfile(imageDir,'mouse.png'));
            self.images.elephant = imread(fullfile(imageDir,'elephant.png'));
        end
    end
end