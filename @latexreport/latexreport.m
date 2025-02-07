classdef latexreport < handle
    %tigwelding Summary of this class goes here
    %   Detailed explanation goes here

    properties
        A = [];
        output_file_path = [];
        ofh = [];

        label_id = 0;
    end

    properties (Constant)
        FIG_FLOAT =0;
        FIG_SUBFLOAT = 1;
    end


    methods(Static)

    end

    methods

        function obj = latexreport(output_file_path)
            obj.output_file_path = output_file_path;            
        end

        function addAnalysisObjectRef(obj, analysis_object)
            obj.A = analysis_object;
        end

        function open(obj)
            obj.ofh = fopen(obj.output_file_path,'w');  % standard output
        end

        function close(obj)
            fclose(obj.ofh);
        end

        function addSection(obj, name)
            f = obj.ofh;
            fprintf(f, '\\section{%s}\n', strrep(name,'_',' ') );
        end

        function addSubSection(obj, name)
            f = obj.ofh;
            fprintf(f, '\\subsection{%s}\n', strrep(name,'_',' ') );
        end
        
        function addSubSubSection(obj, name)
            f = obj.ofh;
            fprintf(f, '\\subsubsection{%s}\n', strrep(name,'_',' ') );
        end
        
        function addParagraphSection(obj, name)
            f = obj.ofh;
            fprintf(f, '\\paragraph{%s}\n', strrep(name,'_',' ') );
        end
        
        function addNewPage(obj)
            f = obj.ofh;
            fprintf(f, '\\newpage\n');
        end
        
        function addPngFigure(obj, fig_type_enum, png_path, s_cap)
            f = obj.ofh;
            if fig_type_enum == latexreport.FIG_SUBFLOAT
                fprintf(f, '\n\\subfloat[%s]\n{\n', s_cap);
                png_path = strrep(png_path,'\','/');
                png_path = strrep(png_path,'_','\_');
                fprintf(f, '   \\includegraphics[width=5in]{%s} \n', png_path);
                fprintf(f,'    \\label{fig:detailed:fig%d}\n',obj.label_id);    
                fprintf(f, '}');
            else
                fprintf(f, '\\begin{figure}[H]\n');
                fprintf(f, '\\centering\n');
                png_path = strrep(png_path,'\','/');
                fprintf(f, '   \\includegraphics[width=5in]{%s} \n', png_path);
                fprintf(f,'    \\label{fig:detailed:fig%d}\n',obj.label_id);    
                fprintf(f, '\\captionsetup{width=5in}\n');  
                fprintf(f, '\\caption{%s}\n', s_cap);
                fprintf(f, '\\end{figure}\n');
            end
            obj.label_id = obj.label_id+1;
        end

    end

end






