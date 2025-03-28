WaveSurfer
==========

WaveSurfer is an application for acquiring electrophysiology
data.  It runs within Matlab R2015b and later (64-bit only).  At
present, you must have a Matlab license to use it.


System Requirements
-------------------

64-bit Windows 7, 8, or 10

National Instruments X Series card (i.e. 63xx)

National Instruments DAQmx driver, version 9.8.x or later.

Matlab R2015b or later (64-bit)


Installation
------------

1.  If you have a previous version of WaveSurfer installed, delete the
    entries for it from your Matlab path.

2.  Download the .zip file for the latest release from here:

        http://wavesurfer.janelia.org/releases/index.html

3.  Extract the .zip file contents to a convenient location.

4.  In Matlab, cd to this just-created directory.

5.  At the Matlab command line, execute "installWavesurfer".  This
    will permanently modify your Matlab path so that all components
    needed by WaveSurfer are on it.  (If you don't want to permanently
    modify the path, execute "installWavesurferForNow" instead of the
    above.  This modifies the path only for the current Matlab
    session.)

6.  At the Matlab command line, execute "wavesurfer".  You should now
    be presented with the WaveSurfer user interface.

7.  Go to Protocol > Device & Channels... to specify what DAQ board you
    want to use, what channels you want to use, and to set channel
    units and scales, if desired.

8.  Go to Protocol > General... to launch the general settings window.
    In it, click the Stimulation > Enabled checkbox to turn on
    stimulation.

9.  In the main window, click the play button (the one with the black
    righward-pointing arrow) to acquire data without saving to disk.
    Click the record button (the one with the red circle) to acquire
    data and save it to disk.

10  To save your device settings, channel settings, and window
    positions, go to File > Save Protocol.  These can then be loaded
    in a new WaveSurfer sessions by going to File > Open Protocol...

11.  If you have questions, please contact the WaveSurfer developers.


Copyright
---------

Except where noted, all code, documentation, images, and anything else
in WaveSurfer is copyright 2013-2022 by the Howard Hughes Medical 
Institute.


License
-------

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

* Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.

* Neither the name of HHMI nor the names of its contributors may be
  used to endorse or promote products derived from this software
  without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


Authors
-------

WaveSurfer was developed at the HHMI Janelia Research Campus.  It
started out as version 3 of Ephus, another electrophysiology package
largely authored by Vijay Iyer, with contributions by Tim O'Connor and
others.

The original developer of WaveSurfer was Patrick Edson.  

WaveSurfer is currently developed by Adam L. Taylor, Ben J. Arthur,
and David Ackerman.


Contributions
-------------

WaveSurfer includes code from the JSONlab project, by 
Qianqian Fang (https://github.com/fangq/jsonlab).  This code is covered 
by its own copyright and licensing.  We thank Dr. Fang for making it 
publicly available.


Support
-------

WaveSurfer is developed at the HHMI Janelia Research Campus. It is
supported by the Svoboda Lab, who initiated the project, and by the
Magee, Spruston, Jayaraman, Lee, Hantman, and Koyama Labs. The project
is coordinated by Janelia's Scientific Computing Software group.


Maintainers
-----------

Adam L. Taylor 
Scientific Computing
HHMI Janelia Research Campus


Version History
---------------

0.74:  (February 26, 2015) Added Axon Multiclamp support.  Now store
       stimulus metadata in the data file header.  Now save data as
       int16 instead of double-precision floating point.  Improved
       ScanImage integration.

0.75:  (March 9, 2015) Fixed bug with scope x-span.

0.76:  (March 11, 2015) Fixed bug with README(!).

0.77:  (March 17, 2015) Now supports timed digital outputs.

0.771: (March 18, 2015) Updated README to reflect true NI DAQmx driver
       requirements.

0.772: (March 18, 2015) Can now change scope y limits during ongoing 
       acquisition.

0.773: (March 23, 2015) Fixed bug with trial duration setting not 
       getting propagated to DAQ board on .cfg file load.

0.774: (March 25, 2015) Fixed a few more bugs.

0.775: (March 25, 2015) Fixed bug that prevented acquisition
       if some AI channels specified in MDF were marked as 
       inactive.

0.776: (April 2, 2015) Added ability to playback arbitrary stimuli
       from .wav file.  Fixed bugs with multiple DO lines and
       long-duration stimuli, and with stimuli not being generated
       properly after 1st stimulus episode when externally triggered.

0.777: (April 3, 2015) Fixed issue that prevented acquisition if
       Matlab was installed on a drive other than the C drive.

0.778: (April 14, 2015) Now have toggle-able autoscaling of y-axis
       limits for both scope windows and the test pulse window.  Added
       per-trialset and per-trial (approximate) timestamps to data
       file.  No longer rely upon DABS callbacks during data
       acquisition, but poll instead.  All internally-generated
       triggers are now themselves triggered off a common "master"
       trigger on PFI8.

0.779: (April 14, 2015) Fixed bug where couldn't test pulse after
       acquiring data.

0.78:  (April 15, 2015) Data files for continuous recordings now use
       the same file naming scheme as trial-based recordings.  Fixed
       bug with fast protocols not getting cleared when you click that
       button.  Added a very simple example user function .m file.

0.781: (April 20, 2015) Added more options for data file naming.  
       Fixed several small bugs.

0.782: (April 22, 2015) Added a two-pulse stimulus.

0.783: (April 22, 2015) Added a generic Matlab expression stimulus.

0.784: (April 29, 2015) Test pulser now uses sampling rate of
       acquisition system.

0.785: (May 11, 2015) Inactived AI channels are now really and 
       truly inactivated.

0.786: (May 12, 2015) Fixed bug with TestPulser model not getting 
       persisted to disk properly.

0.787: (May 12, 2015) Commented out debugging fprintf.  Doh!

0.8:   (May 19, 2015) Added support for digital inputs, untimed digital
       outputs.  Changed user hook function infrastructure to more
       powerful object-based scheme.  Added example user hook classes
       that implement treadmill- and VR-triggered spike rasters.  Many
       other small tweaks and improvements.  Note that version 0.8
       will not generally read protocol files from earlier versions.

0.801: (June 4, 2015) Made electrodes window narrower, so that it fits
       on a 1280x1024 screen.  Added zoom in/out, scroll up/down
       buttons to scope windows, got rid of green-on-black color
       scheme.  Test pulser now shows resistance in units tailored to
       the scale of the resistance value.  Protocol and user settings
       file formats were not changed from release 0.8.

0.802: (June 12, 2015) Fixed error on MDF load under R2013b.  Added
       ability to turn on/off scope grids.  Protocol and user settings
       files from release 0.8+ will still work with this release.

0.803: (June 29, 2015) Fixed bug in ws.loadDataFile() that made it
       error if any channels were not active.  Protocol and user
       settings files from release 0.8+ will still work with this
       release.

0.804: (July 3, 2015) Fixed bug that caused warnings on .cfg load if
       the acquisition sample rate had been changed.  Restored
       green-on-black theme for scope windows as an option.  Scope
       window buttons are now hidden if the window is not tall enough.
       Added option to always hide scope window buttons.  Protocol and
       user settings files from release 0.8+ will still work with this
       release.

0.805: (July 23, 2015) Fixed bug that made it impossible to record if 
       a user class was in use.

0.9-beta-1: (October 12, 2015) Major redesign of WaveSurfer to support
            low-latency (< 5 ms) real-time feedback loops.  WaveSurfer
            now spawns two additional Matlab processes when you lauch
            it: one to aquire data and run real-time feedback loop
            code, and another to ensure that the sweep-based output
            buffer is refilled properly.  Also some streamlining of
            the triggering settings, and changes in terminology
            (e.g. "trials" are now sweeps, an "experiment" is now a
            run).  Note that this is a beta release, so is likely
            somewhat buggier than a regular release.

0.9-beta-2: (October 15, 2015) Fixed several bugs.

0.9-beta-3: (October 15, 2015) Fixed capitalization issues in the
            README.

0.9-beta-4: (October 17, 2015) Fixed another silly cosmetic bug.

0.9-beta-5: (October 29, 2015) Added missing DLL.

0.9-beta-6: (October 30, 2015) Fixed bug where satellite processes 
            didn't have proper search path.

0.9-beta-7: (November 3, 2015) Fixed bug where zero digital inputs 
            caused eventual error during acquisition. 

0.9-beta-8: (November 9, 2015) Fixed several bugs.

0.9-beta-9: (November 9, 2015) Cosmetic fix.

0.9-beta-10: (November 11, 2015) Test Pulser now reports resistance 
             in VC mode, instead of conductance.  Minor improvements 
             to ws.example.RasterTreadMill.

0.9-beta-11: (November 13, 2015) Fixes to WS-SI coordination code.

0.9-beta-12: (November 18, 2015) Fixed bug with triggering schemes, 
             fixed bug with loading older WS data files.

0.9-beta-13: (November 18, 2015) Fixed bug with mimic()'ing cell 
             arrays.

0.9-beta-14: (November 20, 2015) Fixed bug where didn't work if no 
             input channels were defined.

0.9      Dec 01, 2015    Rechristened 0.9-beta-14 as 0.9.

0.901    Jan 07, 2016    Added support for DAQmx 15.1.x.  Fixed bug in
                         error dialog message if the installed version
                         of DAQmx is not supported by WaveSurfer.

0.902    Jan 29, 2016    Fixed triggering issues that could cause acq
                         tasks but not stim tasks to trigger for a 
                         finite-duration sweep, despite nominally 
                         using the same trigger. 

0.91     Feb 12, 2016    All things that used to be set in the MDF
                         file are now settable in the GUI, and stored
                         in the protocol file. 

0.912    Mar 01, 2016    Fixed bug in README.

0.913    Mar 02, 2016    Fixed bug which resulted in actual sampling
                         rate being slightly different from nominal
                         sampling rate for sampling rates (in Hz) that
                         do not evenly divide 100 MHz.

0.914    Mar 11, 2016    Fixed bug where data was saved without
                         scaling coefficients.  Added code to
                         ws.loadDataFile() convert nominal sampling rate
                         for pre-0.913 data files to correct sampling
                         rate.  Added code to ws.loadDataFile() to
                         error if asked to return floating-point
                         (scaled) data when the data file lacks
                         scaling coefficients, as a safeguard.

0.915    Mar 22, 2016    Added tool,
                         ws.addScalingToHDF5FilesRecursively(), to
                         automatically append device scaling
                         information to .h5 data files that currently
                         lack it.

0.916    Apr 14, 2016    All AI channels now explicitly set to
                         differential terminal configuration.
                         Stability and UI improvements.

0.917    Apr 15, 2016    Fixed bug in UI display of AO channel scale
                         units.  Verified bug went no deeper.

0.918    May  8, 2016    Fixed many small bugs, changed
                         TemplateUserClass to ExampleUserClass,
                         cleaned up ws.examples package.

0.919    Jun  1, 2016    Can now set test pulse y limits manually.
                         Satellite Matlab windows are now hidden.
                         Fixed issue with sweep timestamps being
                         somewhat off.  Improved speed of loading
                         protocol files.  Improved handling of old
                         protocol files.  Added ability to duplicate
                         stimulus maps.  Fixed issue with adding
                         scaling coefficients to data files from WS
                         v0.8.

0.9191   Jun 3, 2016     Fixed bug with listing device AI terminals when
                         device has more than 16 (single-ended) AI
                         terminals.

0.9192   Jun 3, 2016     Fixed bug with adding calibration
                         coefficients to old files taken with devices
                         with more than 16 (single-ended) AI
                         terminals.

0.92     Jun 27, 2016    Added support for more recent versions of
                         DAQmx.  Can now duplicate stimuli, maps,
                         sequences.  Better support for old protocol
                         files.  Fixed bug causing errors on stimulus
                         deletion in some cases.  Can now write
                         calibration data to disk, use that file to
                         add calibration to data files.  Fixed bug
                         with electrode AO scaling.  Added debugging
                         mode which shows satellite windows running in
                         full-JVM Matlab sessions.  Added checkbox to
                         optionally turn off electrode gain reading
                         before a run or a test pulse.  Added tooltips
                         to fast protocol buttons.  Improved speed of
                         protocol file loading.  Improvements to
                         display and data scaling speed, especially
                         for long sweeps.  Fixed bug where stopping a
                         run at an unlucky moment would put WS into a
                         weird, unusable state.

0.921    Jul 26, 2016    Fixed another bug with manual stopping.

0.93     Aug 12, 2016    New chart-recorder-like display of traces.
                         Improvements to user class handling.
                         Includes two more custom user classes.
                         
0.931    Aug 23, 2016    Fixed bug with loading protocol file with
                         fewer input channels after taking data.
                       
0.932    Sep 6, 2016     Fixed bug where outputs didn't get zeroed
                         after a user-initiated stop.

0.933    Sep 6, 2016     README bug fix.

0.94     Oct 6, 2016     Changes to triggering to make it more
                         flexible.  Also made satellite processes
                         leaner, and made changes to the stimulus
                         library go through the main WavesurferModel.

0.941    Oct 14, 2016    Run will now continue past end of acquisition
                         if stimulation is ongoing.  Also fixed hangs
                         in some situations.

0.942    Jan 11, 2017    User classes now print debug info to terminal.
                         Updated and streamlined Bias user code.
                         Also fixed bug with map durations loaded
                         from protocol files.

0.943    Feb 22, 2017    Fixes to BIAS-WS interface, incorporating our
                         own version of JSONLab.
                      
0.945    Mar 10, 2017    Bug fix for MultiClamp 700A support.

0.946    Apr 3, 2017     Added support for MultiClamp 700B Commander 2.2.
                         Fixed bug with y auto-scaling.
                         Enhanced ws.examples.TriggerOnThresholdCrossingClass.

0.947    Apr 6, 2017     Added support for very-low sampling rates, 
                         down to ~1/(40 s).
                         
0.95     Aug 9, 2017     Improved SI-WS integration, now using SI-WS
                         communication protocol version 2.0.0.  Input
                         signals now displayed in main window,
                         acquisition/stimulation settings moved to
                         "General" window.  Eliminated direct external
                         access to WavesurferModel subsystems in user
                         code.  Eliminated Parent properties in all
                         ws.Model objects.
                         
0.951    Aug 24, 2017    Fixed bug where WS used built-in contains()
                         function, only introduced in R2016b.
                       
0.952    Aug 25, 2017    Fixed bug where Channels window didn't
                         properly update after changes in the
                         Electrodes window.
                  
0.96     Sep 5, 2017     Added support for multiple DAQ boards.

0.961    Oct 14, 2017    Bug fixes.

0.962    Oct 18, 2017    Added new stimulus type.  Streamlined
                         handling of stimulus parameters.

0.963    Oct 18, 2017    Fixed bug.

0.964    Oct 19, 2017    Fixed bug with two square pulse stimulus.

0.965    Dec 13, 2017    Added Micro-Manager user class.  Fixed bugs.

0.966    Jan 29, 2018    Fixed bug with untimed DO during TP not
                         working.

0.967    Feb 1, 2018     Fixed bug with stim library figure not
                         getting updated after protcol file load.
                         
0.968    Feb 5, 2018     Fixed bugs with user code management.
                    
0.97     Feb 7, 2018     Added wake() method to user classes.

0.98     Sep 13, 2018    Improvements to ws.loadDataFile().

0.981    Oct 1, 2018     Bug fixes.

0.982    Apr 6, 2019     Fixed bug with finding NI DAQmx .h file.
                         Fixed bug with HEKA integration in Matlab
                         2018a/b.  Added example user class for
                         controlling Hantman Lab pez dispenser.  Added
                         new user class method,
                         willSaveToProtocolFile().  File stimulus can
                         now load a .mat file.  Fixed a few other bugs.
                         
1.0      Apr 14, 2019    User settings files have been replaced with
                         user profiles that act as preferences,
                         requiring less user fiddling.  WaveSurfer
                         now does a better job of warning the user
                         when they try to close a protocol with
                         unsaved changes.  Stimulus preview is no
                         longer a second-class window, and now
                         automatically updates when the current
                         stimulus/map/sequence is changed.  Dropped
                         support for soft-real-time controllers in
                         user code.  Dropped support for Matlab 2014b
                         and 2015a.
                         
1.0.1    May 11, 2019    Fixed bugs.  Pez controller example code is
                         now suitable for the v2 pez dispenser.
                         Switched to semantic versioning
                         (https://semver.org/).

1.0.2    Jun 05, 2019    Fixed bug with opening old protocol files.

1.0.5    Dec 01, 2020    Updates to pez controller example.  Added
                         method to query whether logging is enabled
                         to ws.WavesurferModel.

1.0.6    Apr 25, 2022    Fixed bug with TP not updating in recent 
                         Matlab versions, and TP window not 
                         resizing properly.

