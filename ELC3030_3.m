clear all;clc;
%define global variables to be used in functions
global config output input_text frames frames_to_be_plotted...
    length_of_frame NRZI_plus NRZI_minus second_packet_end file_size;
%open and read the configuration file of UART and USB
fileName = 'conf.json';
fid = fopen(fileName);
raw = fread(fid,inf);
str_input = char(raw');
fclose(fid);
%create configuration structure to store configuration desired by the user 
config= jsondecode(str_input);

%read the text file required to be sent and get its size
fileName = 'inputdata.txt';
input_file = dir(fileName);
initial_file_size=input_file.bytes;
fid = fopen(fileName);
input_text= double(fread(fid));
fclose( fid ) ;
file_size=initial_file_size;
output(1).protocol_name="UART";
output(2).protocol_name="USB";
%display error message when wrong protocol are provided by the user
if(config(1).protocol_name~="UART")
    output(1).outputs.efficiency=0;
    output(1).outputs.overhead=0;
    output(1).outputs.total_tx_time=0;
    fprintf('\nINVALID SERIAL COMMUNICATION PROTOCOL in the 1st object of the configuration file array!\n\n');
end
if(config(2).protocol_name~="USB")
    output(2).outputs.efficiency=0;
    output(2).outputs.overhead=0;
    output(2).outputs.total_tx_time=0;
    fprintf('\nINVALID SERIAL COMMUNICATION PROTOCOL in the 2nd object of the configuration file array!\n\n');
end

%execute this block of code if we have same bit duration for UART and USB
if(config(1).parameters.bit_duration==config(2).parameters.bit_duration&&...
        config(1).protocol_name=="UART"&&config(2).protocol_name=="USB")
    step_size=7;
    %loop to calculate main parameters (efficiency,overhead and total tx time)
    %many times to plot them versus file size
    for step_number=0:floor(initial_file_size/step_size)
        %clear old variables to do new calculations 
        clearvars -except input_text config output file_size step_size step_number...
            USB_efficiency USB_overhead USB_total_tx_time UART_efficiency...
            UART_overhead UART_total_tx_time initial_file_size
           %concatinate some bytes with the original text file array to plot overhead
           %and total tx time versus file size
        if(step_number>0)
            input_text=cat(1,input_text,input_text(step_size*(step_number-1)+1:step_size*step_number));
            file_size=length(input_text);
        end
        %call the main function
        main
        %store outputs calculated after executing the program for the first time
        %and plot the required frames and packets of UART and USB
        if(step_number==0)
            str_output = jsonencode(output);
            str_output=prettyjson(str_output);
            fid=fopen('ELC3030_3.json','w');
            fprintf(fid,str_output);
            fclose(fid);
            if(config(1).protocol_name=="UART")
                UART_plot_two_bytes
            end
            if(config(2).protocol_name=="USB")
                USB_plot_two_packets
            end
        end
        %store parameters calculated every time in arrays to be plotted
        if(step_number>0)
            if(config(1).protocol_name=="UART")
                UART_efficiency(step_number)=output(1).outputs.efficiency;
                UART_overhead(step_number)=output(1).outputs.overhead;
                UART_total_tx_time(step_number)=output(1).outputs.total_tx_time;
            end
            if(config(2).protocol_name=="USB")
                USB_efficiency(step_number)=output(2).outputs.efficiency;
                USB_overhead(step_number)=output(2).outputs.overhead;
                USB_total_tx_time(step_number)=output(2).outputs.total_tx_time;
            end
        end
    end
    %plot UART parameters
    if(config(1).protocol_name=="UART")
        size=[(initial_file_size+1):step_size:(2*step_size*floor(initial_file_size/step_size))];
        figure
        plot(size,UART_efficiency)
        title('UART efficiency VS file size')
        figure
        plot(size,UART_overhead)
        title('UART overhead VS file size')
        figure
        plot(size,UART_total_tx_time)
        title('UART total tx time VS file size')
    end
    %plot UART parameters
    if(config(2).protocol_name=="USB")
        size=[(initial_file_size+1):step_size:(2*step_size*floor(initial_file_size/step_size))];
        figure
        plot(size,USB_efficiency)
        title('USB efficiency VS file size')
        figure
        plot(size,USB_overhead)
        title('USB overhead VS file size')
        figure
        plot(size,USB_total_tx_time)
        title('USB total tx time VS file size')
    end
else
    main
    %write the output structure in the output file
    str_output = jsonencode(output);
    str_output=prettyjson(str_output);
    fid=fopen('ELC3030_3.json','w');
    fprintf(fid,str_output);
    fclose(fid);
    %plot the required frames and packets of UART and USB
    if(config(1).protocol_name=="UART")
        UART_plot_two_bytes
    end
    if(config(2).protocol_name=="USB")
        USB_plot_two_packets
    end
end

%main function which calls UART and USB functions 
function main()
global config
if(config(1).protocol_name=="UART")
    UART();
end
if(config(2).protocol_name=="USB")
    USB();
end
end

%UART function to form the frames to be sent
function UART()
%define required global variables required in this function
global config input_text file_size output frames frames_to_be_plotted...
    length_of_frame;
%convert ascii values to 7bit binary
text_binary=de2bi(input_text,7);
data_UART=transpose(text_binary);
%calculate the number of remaining bits to be sent in the last frame
%with the other data bits in this frame padded
if(config(1).parameters.data_bits==7)
    number_of_frames=file_size;
elseif(config(1).parameters.data_bits==8)
    number_of_frames=ceil((7*file_size)/8);
    remainder_UART=rem((7*file_size),8);
    data_UART=reshape(data_UART,[],1);
    if(remainder_UART>0)
        data_UART=wextend('1D','zpd',data_UART,8-remainder_UART,'d');
    end
    %reshape data to be rows of 8bits in case of 8bit mode
    data_UART=reshape(data_UART,8,[]);
end
%create row of start bits
start_bits=zeros(1,number_of_frames);

%generate parity bit (if required) of each frame
if(config(1).parameters.parity~="none")
    for i=1:number_of_frames
        num_of_ones=0;
        for j=1:config(1).parameters.data_bits
            if (data_UART(j,i)==1)
                num_of_ones=num_of_ones+1;
            end
        end
        if(config(1).parameters.parity=="even")
            parity(i)=rem(num_of_ones,2);
        elseif(config(1).parameters.parity=="odd")
            parity(i)=1-rem(num_of_ones,2);
        end
    end
end
%create row of stop bits
stop_bits=ones(config(1).parameters.stop_bits,number_of_frames);

%create frames matrix
if(config(1).parameters.parity=="none")
    frames=[start_bits;data_UART;stop_bits];
else
    frames=[start_bits;data_UART;parity;stop_bits];
end

%calculate UART required parameters and store it in the output structure
length_of_frame=length(frames(:,1));
frames=reshape(frames,[],1);
frames_to_be_plotted=frames(1:2*length_of_frame+1,1);
output(1).outputs.efficiency=(7*file_size)/length(frames);
output(1).outputs.overhead=1-output(1).outputs.efficiency;
output(1).outputs.total_tx_time=length(frames)*config(1).parameters.bit_duration;
end

%USB function to form the packets to be sent
function USB()
%define required global variables required in this function
global config input_text file_size output NRZI_plus NRZI_minus...
    second_packet_end
%convert ascii values to 7bit binary
text_binary=de2bi(input_text,7);

payload=config(2).parameters.payload;
data_USB=transpose(text_binary);

%calculate the number of remaining bytes to be sent in the last packet
%with the other data bytes in this packet padded
remainder=rem(7*file_size,payload*8);
num_of_packets=(7*file_size-remainder)/(payload*8);
data_USB=reshape(data_USB,[],1);
if(remainder>0)
    last_packet_payload=data_USB(end-remainder+1:end);
    last_packet_payload=wextend('1D','zpd',last_packet_payload,payload*8-remainder,'d');
    %when remainder=1 the extension is done to the row not col so the
    %extension when remainder=1 is done individually
    if (remainder==1)
        last_packet_payload=last_packet_payload';
    end
    data_USB=data_USB(1:(file_size*7-remainder));
end

%create address column vector
address=double(config(2).parameters.dest_address)-'0';
address=fliplr(address);
address=transpose(address);
%create sync pattern column vector
sync=double(config(2).parameters.sync_pattern)-'0';
sync=transpose(sync);

if(num_of_packets>0)
    payload_data=reshape(data_USB,payload*8,[]);
    %create packet ID for each packet from 1 to 15 (from 0000 to 1111)
    packet_ID=zeros(1,num_of_packets)';
    for i=1:(num_of_packets)
        packet_ID(i)=rem(i,16);
    end
    PID_first_4bits=de2bi(packet_ID,4);
    %last 4bits in PID is the inversion of the first 4bits
    PIds=[PID_first_4bits ~PID_first_4bits]';
    %same sync pattern and address for all packets
    sync_matrix=repmat(sync,1,num_of_packets);
    address_matrix=repmat(address,1,num_of_packets);
    final_matrix=[sync_matrix;PIds;address_matrix;payload_data];
end
%handle the last packet
if(remainder>0)
    num_of_packets=num_of_packets+1;
    last_PID_first_4bits=de2bi(rem((num_of_packets),16),4);
    last_PID=[last_PID_first_4bits ~last_PID_first_4bits]';
    last_packet=[sync;last_PID;address;last_packet_payload];
    %form the final matrix that contains all packets
    if(num_of_packets==1)
        final_matrix=last_packet;
    else
        final_matrix=[final_matrix last_packet];
    end
end
%reshape packets to be in a column vector to do bit stuffing
sent_packets=reshape(final_matrix,[],1);
%define EOP with a unique digit to know their place after but stuffing
EOP=5;
num_of_ones=0;
counter=0;
%do bit stuffing for all packets
for i=1:length(sent_packets)
    if (sent_packets(i)==1)
        num_of_ones=num_of_ones+1;
    else
        num_of_ones=0;
    end
    if (num_of_ones==6)
        counter=counter+1;
        packets_bit_stuffing(counter)=sent_packets(i);
        counter=counter+1;
        %insert zero bit if a pattern of 6 ones is found
        packets_bit_stuffing(counter)=0;
        num_of_ones=0;
    else
        counter=counter+1;
        packets_bit_stuffing(counter)=sent_packets(i);
    end
    %mark place of EOP
    if (rem(i,(length(sent_packets)/num_of_packets))==0)
        counter=counter+1;
        packets_bit_stuffing(counter)=EOP;
    end
end
%create the diffretial signals
NRZI_plus(1)=1;
NRZI_minus(1)=0;
counter=1;
number_of_packets=0;
%keep data line when finding 1 and invert it when fiding 0
for i=1:length(packets_bit_stuffing)
    counter=counter+1;
    if(packets_bit_stuffing(i)==0)
        NRZI_plus(counter)=not(NRZI_plus(counter-1));
        NRZI_minus(counter)=not(NRZI_minus(counter-1));
    elseif(packets_bit_stuffing(i)==1)
        NRZI_plus(counter)=NRZI_plus(counter-1);
        NRZI_minus(counter)=NRZI_minus(counter-1);
    elseif(packets_bit_stuffing(i)==EOP)
        %put 2bit EOP which are sent single ended not diffrentially
        number_of_packets=number_of_packets+1;
        NRZI_plus(counter)=0;
        NRZI_minus(counter)=0;
        counter=counter+1;
        NRZI_plus(counter)=0;
        NRZI_minus(counter)=0;
        counter=counter+1;
        NRZI_plus(counter)=1;
        NRZI_minus(counter)=0;
        if(number_of_packets==2)
            second_packet_end=counter;
        end
    end
end
%calculate USB required parameters and store it in the output structure
n_sent_bits=length(packets_bit_stuffing)+num_of_packets;
output(2).outputs.efficiency=((file_size*7)/n_sent_bits);
output(2).outputs.overhead=1-output(2).outputs.efficiency;
output(2).outputs.total_tx_time=n_sent_bits*config(2).parameters.bit_duration;
end

%function to plot the first two bytes sent by the UART
function UART_plot_two_bytes()
%define required global variables required in this function
global frames_to_be_plotted length_of_frame;
figure
stairs(frames_to_be_plotted);
title('UART first two bytes');
set(gca,'XTick',1:2*length_of_frame+1);
%set X and Y axis limits
xlim([1 2*length_of_frame+1]);
ylim([-0.1 1.1]);
end

%function to plot the first two packets sent by the USB
function USB_plot_two_packets()
%define required global variables required in this function
global NRZI_plus NRZI_minus second_packet_end;
figure
stairs(NRZI_plus(1:second_packet_end));
title('USB D+(NRZI plus) first two packets');
xlim([1 second_packet_end]);
ylim([-0.1 1.1]);

%first 30 bits of D+
figure
stairs(NRZI_plus(1:30));
title('USB D+(NRZI plus) first 30 bits');
xlim([1 30]);
ylim([-0.1 1.1]);

%last 30 bits of the second packet of D-
figure
stairs([second_packet_end-30:second_packet_end],...
    NRZI_plus(second_packet_end-30:second_packet_end));
title('USB D+(NRZI plus) last 30 bits of the second packet');
xlim([second_packet_end-30 second_packet_end]);
ylim([-0.1 1.1]);

figure
stairs(NRZI_minus(1:second_packet_end));
title('USB D-(NRZI minus) first two packets');
%set X and Y axis limits
xlim([1 second_packet_end]);
ylim([-0.1 1.1]);

%first 30 bits of D-
figure
stairs(NRZI_minus(1:30));
title('USB D-(NRZI minus) first 30 bits');
xlim([1 30]);
ylim([-0.1 1.1]);

%last 30 bits of the second packet of D-
figure
stairs([second_packet_end-30:second_packet_end],...
    NRZI_minus(second_packet_end-30:second_packet_end));
title('USB D-(NRZI minus) last 30 bits of the second packet');
xlim([second_packet_end-30 second_packet_end]);
ylim([-0.1 1.1]);
end

% Makes JSON strings (relatively) pretty
function [less_ugly] = prettyjson(ugly)
% Probably inefficient

% Mostly meant for structures with simple strings and arrays;
% gets confused and !!mangles!! JSON when strings contain [ ] { or }.

MAX_ARRAY_WIDTH = 80;
TAB = '    ';

ugly = strrep(ugly, '{', sprintf('{\n'));
ugly = strrep(ugly, '}', sprintf('\n}'));
ugly = strrep(ugly, ',"', sprintf(', \n"'));
ugly = strrep(ugly, ',{', sprintf(', \n{'));
ugly = strrep(ugly, ':', ': ');

indent = 0;
lines = splitlines(ugly);

for i = 1:length(lines)
    line = lines{i};
    next_indent = 0;
    
    % Count brackets
    open_brackets = length(strfind(line, '['));
    close_brackets = length(strfind(line, ']'));
    
    open_braces = length(strfind(line, '{'));
    close_braces = length(strfind(line, '}'));
    
    if close_brackets > open_brackets || close_braces > open_braces
        indent = indent - 1;
    end
    
    if open_brackets > close_brackets
        line = strrep(line, '[', sprintf('['));
        next_indent = 1;
    elseif open_brackets < close_brackets
        line = strrep(line, ']', sprintf('\n]'));
        next_indent = -1;
    elseif open_brackets == close_brackets && length(line) > MAX_ARRAY_WIDTH
        first_close_bracket = strfind(line, ']');
        if first_close_bracket > MAX_ARRAY_WIDTH % Just a long array -> each element on a new line
            line = strrep(line, '[', sprintf('[\n%s', TAB));
            line = strrep(line, ']', sprintf('\n]'));
            line = strrep(line, ',', sprintf(', \n%s', TAB)); % Add indents!
        else % Nested array, probably 2d, first level is not too wide -> each sub-array on a new line
            line = strrep(line, '[[', sprintf('[\n%s[', TAB));
            line = strrep(line, '],', sprintf('], \n%s', TAB)); % Add indents!
            line = strrep(line, ']]', sprintf(']\n]'));
        end
    end
    
    sublines = splitlines(line);
    for j = 1:length(sublines)
        if j > 1   % todo: dumb to do this check at every line...
            sublines{j} = sprintf('%s%s', repmat(TAB, 1, indent+next_indent), sublines{j});
        else
            sublines{j} = sprintf('%s%s', repmat(TAB, 1, indent), sublines{j});
        end
    end
    
    if open_brackets > close_brackets || open_braces > close_braces
        indent = indent + 1;
    end
    indent = indent + next_indent;
    lines{i} = strjoin(sublines, newline);
    
end

less_ugly = strjoin(lines, newline);
end








