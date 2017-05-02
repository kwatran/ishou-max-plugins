global sekaiInstaller;

--Re-init update.ms to work around update bug in 2.1
-- try ( fileIn ((GetDir #userScripts) + "/sekai/update.ms"); ) catch ()

rollout sekai_install ""
(
   edittext progress_txt height:200 readonly:true width:278 align:#center offset:[-1, 0];
   progressbar progress_bar value:0 width:273 align:#center;
   button close_btn "Close" enabled:false width:273 align:#center    
   on close_btn pressed do
      destroyDialog sekai_install;
)

struct sekai_installer (


--Directories and files.
private tempDir              = (GetDir #temp) + "/sekai",
private strings_file         = tempDir + "/installer/strings.ini",
private installer_data_file  = tempDir + "/installer/installer_data.ini",
private userUIDir            = pathConfig.removePathLeaf (GetDir #userIcons),
private userScriptDir        = (GetDir #userScripts) + "/sekai",
private userIconsDir         = (GetDir #userIcons),
private prefs_file           = (GetDir #userScripts) + "/sekai_prefs.ini",
private user_colors_file     = (GetDir #userScripts) + "/sekai_user_colors.ini",
private product_info_file    = (GetDir #userScripts) + "/sekai_product_info.ini",


--Retrieves the string from the strings ini file.
public function getString key section:#Strings = 
(
   local str;
   if (section != undefined AND key != undefined) do
      str = getINISetting strings_file section key;
   
   if (str == undefined) do 
   (
      print ("Installer: cannot find string " + key + " in section " + section);
      str = "";
   )
   
   --Replace escaped newline characters and return result.
   substituteString str "\\n" "\n";
),


--Returns the version of this installer.
public function getVersion asString:false =
(
   if (not asString) then
      (getINISetting installer_data_file #Version #version) as float;
   else
      getINISetting installer_data_file #Version #versionString
),


--Returns the version of the currently installed
public function getInstalledVersion =
(
   local v = 0.0;
   if (hasINISetting product_info_file #General #version) then
      v = (getINISetting product_info_file #General #version) as float;
   else if (hasINISetting prefs_file #General #version) then
      v = (getINISetting product_info_file #General #version) as float;
   
   v;
),


--Returns true if the Program is installed for this 3dsmax installation.
public function getIsSekaiInstalled =
(
   (getINISetting product_info_file #General #sekaiInstalled) == "true";
),

private function setIsSekaiInstalled i =
(
   setINISetting product_info_file #General #sekaiInstalled (i as string);
),


--Returns true if the Workflow Tools are installed for this 3dsmax installation.
public function getIsWorkflowToolsInstalled =
(
   (getINISetting product_info_file #General #workflowtoolsinstalled) == "true";
),

private function setIsWorkflowToolsInstalled i =
(
   setINISetting product_info_file #General #workflowtoolsinstalled (i as string);
),


--Load an assembly with shadow-copy enabled.
private function loadAssembly dll =
(
   local AppDomain    = dotNetClass "System.AppDomain";
   local AssemblyName = dotNetClass "System.Reflection.AssemblyName";

   AppDomain.CurrentDomain.SetShadowCopyPath (GetDir #temp);
   AppDomain.CurrentDomain.SetShadowCopyFiles();

   local assemblyName = AssemblyName.GetAssemblyName dll;
   AppDomain.CurrentDomain.Load assemblyName;
),


--Closes if it's still opened.
private function closeSekai =
(
   try ( sekai.ui.closeSekai(); ) catch ()
   try ( sekai.destroy(); ) catch ()
   global sekai = undefined;
),


--Prints an exception message to the maxscript listener.
private function printException executingFn exception =
(
   print "** Installer exception **\n%\n%\n" executingFn exception;
),


--Adds a post-system-shutdown callback that removes the temporary files.
public function clearTempDir =
(
   local scriptStr = ("local d = (GetDir #temp) + \"/sekai\";
      if ((dotNetClass \"System.IO.Directory\").Exists d) do 
         try ( (dotNetClass \"System.IO.Directory\").Delete d true; ) catch ()");
   
   callbacks.removeScripts #preSystemShutdown id:#sekai_installer;
   callbacks.addScript #preSystemShutdown scriptStr id:#sekai_installer;
),



/**
 * UNINSTALL FUNCTIONS
 */
private function removeScriptFiles =
(
   local success = true;
   
   closeSekai();
   
   local System_IO_Directory = dotNetClass "System.IO.Directory";
   
   --Delete all script files (old and current).
   local oldSekaiDirs = #(
      ((GetDir #Scripts) + "/sekai"), 
      ((GetDir #maxroot) + "/stdplugs/stdscripts/sekai"),
      ((GetDir #ui) + "/macroscripts/sekai"),
      ((GetDir #userMacros) + "/sekai"),
      userScriptDir
   );
   for d in oldSekaiDirs where (System_IO_Directory.Exists d) do 
   (
      try (
         System_IO_Directory.Delete d true;
      ) catch 
      (
         printException "removeScriptFiles" (getCurrentException());
         success = false;
      )
   )
   
   --Delete other startup files. (in stdscripts)
   local otherStartupFiles = getFiles ((GetDir #maxroot) + "/stdplugs/stdscripts/sekai*");
   for f in otherStartupFiles do
   (
      if (not (deleteFile f)) do
         success = false;
   )
   
   -- Remove user macros
   local userMacroDir = (GetDir #userMacros);
   local oldUserMacros = (getFiles (userMacroDir + "/*Sekai*"));
   for mcr in oldUserMacros do 
   (
      if (not (matchPattern mcr pattern:"*Sekai Workflow Tools*")) do
      (
         if (not (deleteFile mcr)) do 
            success = false;
      )
   )

   success;
),

private function removeWorkflowTools =
(
   local success = true;
   
   local System_IO_Directory = dotNetClass "System.IO.Directory";
   local oldWfToolsDir = (GetDir #userMacros) + "/sekai_workflowtools";
   if (System_IO_Directory.Exists oldWfToolsDir) do
   (
      try (
         System_IO_Directory.delete workflowtoolsDir true;
      ) catch 
      (
         printException "removeWorkflowTools" (getCurrentException());
         success = false;
      )
   )
   
   -- Remove icon files
   local iconFiles = getFiles ((GetDir #ui) + "/icons/*Sekai_wftools*");
   for ico in iconFiles do
   (
      if (not (deleteFile ico)) do 
         success = false;
   )
   iconFiles = getFiles (userIconsDir + "/*Sekai_wftools*");
   for ico in iconFiles do
   (
      if (not (deleteFile ico)) do 
         success = false;
   )


   -- Remove user macros
   local userMacroDir = (GetDir #userMacros);
   local oldUserMacros = (getFiles (userMacroDir + "/*Sekai Workflow Tools*"));
   for mcr in oldUserMacros do 
   (
      if (not (deleteFile mcr)) do success = false;
   )
   
   setIsWorkflowToolsInstalled false; 

   success;
),


private function removeHotkeys =
(
   local success = true;
   try
   (
      local kbdFileClass = dotnetClass "ScriptCenter.Max.KbdFile";
      local kbdFile      = dotnetObject "ScriptCenter.Max.KbdFile" \
                                        (kbdFileClass.MaxGetActiveKbdFile());
      
      if ((kbdFile.RemoveAction "Sekai") > 0) do
      (
         kbdFile.Write();
         kbdFile.MaxLoadKbdFile();
      )
   )
   catch 
   (
      printException "removeHotkeys" (getCurrentException());
      success = false;
   )
   
   success;
),



/**
 * INSTALL FUNCTIONS
 */
 
private function updatePreferencesFile =
(
   local oldVersion = getInstalledVersion();

   --Write version and update settings.
   setINISetting product_info_file #General #version ((getVersion()) as string);
   setINISetting product_info_file #General #versionString (getVersion asString:true);
   
   true;
),

private function copyDirectory sourceDir targetDir =
(
   local Directory    = dotNetClass "System.IO.Directory";
   local SearchOption = dotNetClass "System.IO.SearchOption";
   local File         = dotNetClass "System.IO.File";
   local allFiles = Directory.GetFiles sourceDir \
                                       "*.*" \
                                       SearchOption.AllDirectories;
   
   for sourceFile in allFiles do
   (
      local targetFile = targetDir + (substring sourceFile (sourceDir.count + 1) -1);
      local targetFileDir = getFilenamePath targetFile;
      if (not (Directory.Exists targetFileDir)) do
         Directory.CreateDirectory targetFileDir;
      File.Copy sourceFile targetFile;
   )
),



private function copyScriptFiles = 
(
   local success = true;
   
   local Directory = dotNetClass "System.IO.Directory";
   local File      = dotNetClass "System.IO.File";
   
   try 
   (
      copyDirectory (tempDir + "/scripts") userScriptDir;
   )
   catch 
   (
      printException "copyScriptFiles" (getCurrentException());
      success = false;
   )
   
   success;
),


private function loadMacroScripts =
(
   local success = true;
   --try
   --(
   print "get files"
   local files = GetFiles (tempDir + "/macroscripts/*.mcr");
   for file in files do
      --print ("loading a file..." + file as string)
      fileIn file;
      --print ("able to load file..." + file as string)
   --)
   --catch
  -- (
      -- printException "loadMacroScripts" (getCurrentException());
   --   success = false;
   --)
   
   success;
),


--Returns the currently active cui file if it can be written to,
--otherwise it saves a new config file in the userUI dir.
private function getActiveCuiFile =
(
   local configFile = cui.getConfigFile();
   if (not (doesFileExist configFile) OR 
       not (getFileSecurityInfo configFile #write)) do
   (
      configFile = pathConfig.appendPath userUIDir (filenameFromPath configFile);
   )
   
   cui.saveConfigAs configFile;
   
   configFile;
),


--Returns the currently active kbd file if it can be written to,
--otherwise it saves a new config file in the userUI dir.
private function getActiveKbdFile =
(
   local configFile = actionMan.getKeyboardFile();
   if (not (doesFileExist configFile) OR
       not (getFileSecurityInfo configFile #write)) do
   (
      configFile = pathConfig.appendPath userUIDir (filenameFromPath configFile);
   )
   
   actionMan.saveKeyboardFile configFile;
   
   configFile;
),
private function containsHotkeyAction macroName macroCategory =
(
   local result = false;
   try
   (
      local kbdFileClass = dotnetClass "ScriptCenter.Max.KbdFile";
      local kbdFile      = dotnetObject "ScriptCenter.Max.KbdFile" \
                                        (getActiveKbdFile());
                                        
      result = kbdFile.ContainsAction macroName macroCategory;
   )
   catch 
   (
      printException "getHotkeyAction" (getCurrentException());
   )
   
   result;
),


private function getHotkeyAction =
(
   local action;
   try
   (
      local keysClass    = dotnetClass "System.Windows.Forms.Keys";
      local kbdFileClass = dotnetClass "ScriptCenter.Max.KbdFile";
      local kbdFile      = dotnetObject "ScriptCenter.Max.KbdFile" \
                                        (getActiveKbdFile());
                                        
      action = kbdFile.GetAction keysClass.H;
   )
   catch 
   (
      printException "getHotkeyAction" (getCurrentException());
   )
   
   action;
),


private function assignHotkey = 
(
   local success = true;
   try
   (  
      local keysClass    = dotnetClass "System.Windows.Forms.Keys";
      local kbdFileClass = dotnetClass "ScriptCenter.Max.KbdFile";
      local kbdFile      = dotnetObject "ScriptCenter.Max.KbdFile" \
                                        (getActiveKbdFile());

      if (kbdFile.AddAction "toggleSekai" "Sekai" keysClass.H) do
      (
         kbdFile.Write();
         kbdFile.MaxLoadKbdFile();
      )
   )
   catch
   (
      printException "assignHotkey" (getCurrentException());
      success = false;
   )
   
   success;
),


public function openInstallWindow height =
(
   try ( destroyDialog sekai_install ) catch ()
   
   createDialog sekai_install 300 \
                              height \
                              lockWidth:true \
                              lockHeight:true \
                              style:#(#style_sysmenu, #style_toolwindow)
   
   sekai_install.progress_txt.height = height - 60;
   sekai_install.progress_bar.pos.y  = height - 48;
   sekai_install.close_btn.pos.y     = height - 28;
),



private function setStatusTitle txt =
(
   if (sekai_install.open) do
      sekai_install.title = txt;
),

private function addStatusText txt newline:true progress:0 =
(
   if (sekai_install.open) do
   (
      if (newline AND sekai_install.progress_txt.text != "") do 
         txt = "\n" + txt;
      
      sekai_install.progress_txt.text += txt;
      sekai_install.progress_bar.value += progress;
   )
),



private function installation_success inst silent:false showHowToUse:false =
(
   if (not silent) do
   (
      local inst_txt = (getString #instSuccess);
      
      addStatusText "";
      addStatusText inst_txt progress:100;
      
      sekai_install.close_btn.enabled = true;
      
      if (showHowToUse) do
         inst_txt += (getString #howto);
      
      local mb     = dotNetClass "System.Windows.Forms.MessageBox";
      local mbBtn  = dotNetClass "System.Windows.Forms.MessageBoxButtons";
      local mbIcon = dotNetClass "System.Windows.Forms.MessageBoxIcon";
      mb.Show inst_txt \
              (getString #instSuccess)\
              mbBtn.OK \
              mbIcon.Information;
   )
),

private function uninstallation_success silent:false =
(
   if (not silent) do
   (
      addStatusText "";
      addStatusText (getString #uninstSuccess) progress:100;
      sekai_install.close_btn.enabled = true;
      
      local mb     = dotNetClass "System.Windows.Forms.MessageBox";
      local mbBtn  = dotNetClass "System.Windows.Forms.MessageBoxButtons";
      local mbIcon = dotNetClass "System.Windows.Forms.MessageBoxIcon";
      mb.Show (getString #uninstSuccessMsg) \
              (getString #uninstSuccess) \
              mbBtn.OK \
              mbIcon.Information;
   )
),

private function installation_failed inst msg silent:false =
(
   if (not silent) do
   (
      addStatusText ("\n\n" + inst + " " + (getString #failed));
      sekai_install.close_btn.enabled = true;
      messageBox msg title:(getString #error);
   )
),




/**
 * RUN UNINSTALL
 */
public function uninstall silent:false =
(
   local progressDelta = ceil (100.0 / 5); --where 5 is the number of uninstallation steps.

   if (not silent) do
   (
      openInstallWindow 170;
      setStatusTitle ((getString #title) + " " + (getString #uninst));
      addStatusText (getString #begUnInst);
   )
      
   print "Remove script files"
   addStatusText (getString #remScriptFiles);
   if (removeScriptFiles()) then
      addStatusText (getString #done) newline:false progress:progressDelta;
   else
   (
      addStatusText (getString #failed) newline:false;
      installation_failed (getString #uninst) \
                          (getString #remScriptFiles section:#Error) \
                          silent:silent;
      return false;
   )
   
   print "Remove Workflow Tools"
   if (getIsWorkflowToolsInstalled()) do
   (
      addStatusText (getString #remWFTools);
      if (queryBox (getString #remWFTools section:#Queries) \
                   title:(getString #remWFToolsTitle section:#Queries)) then
      (
         if (removeWorkflowTools()) then
            addStatusText (getString #done) newline:false progress:progressDelta;
         else
         (
            addStatusText (getString #failed) newline:false;
            installation_failed (getString #uninst) \
                                (getString #remWFTools section:#Error) \
                                 silent:silent;
            return false;
         )
      )
      else
         addStatusText (getString #skipped) newline:false;
   )
   
   print "Remove hotkeys"
   addStatusText (getString #remHotkeys);
   if (removeHotkeys()) then
   (
      addStatusText (getString #done) newline:false progress:progressDelta;
   )
   else
   (
      addStatusText (getString #failed) newline:false;
      installation_failed (getString #uninst) \
                          (getString #remHotkeys section:#Error) \
                           silent:silent;
      return false;
   )
   
   setIsSekaiInstalled false;   
   uninstallation_success silent:silent;
   
   true;
),--End uninstall function.



/**
 * RUN INSTALL
 */
public function install silent:false =
(   
   print "Uninstall Previous Version"
   addStatusText (getString #uninstPrevVer);
   if (removeScriptFiles()) then
      addStatusText (getString #done) newline:false progress:progressDelta;
   else
   (
      print "ERROR: removeScriptFiles() Failed"
      addStatusText (getString #failed) newline:false;
      installation_failed (getString #inst) \
                          (getString #uninstPrev section:#Error) \
                          silent:silent;
      return false;
   )

   print "Check Settings"
   addStatusText (getString #updPrefFile);
   if (updatePreferencesFile()) then
      addStatusText (getString #done) newline:false progress:progressDelta;
   else
   (
      print "ERROR: updatePreferencesFile() Failed"
      addStatusText (getString #failed) newline:false;
      installation_failed (getString #inst) \
                          (getString #updatePrefsFile section:#Error) \
                          silent:silent;
      return false;
   )

   print "Copy new files"
   addStatusText (getString #cpNewFiles);
   if (copyScriptFiles()) then
      addStatusText (getString #done) newline:false progress:progressDelta;
   else
   (
      print "ERROR: copyScriptFiles() Failed"
      addStatusText (getString #failed) newline:false;
      installation_failed (getString #inst) \
                          (getString #copyNewFiles section:#Error) \
                          silent:silent;
      return false;
   )

   print "Load macroscripts"
   addStatusText (getString #loadMcr);
   print "Starting macro load"
   if (loadMacroScripts()) then
   (
      addStatusText (getString #done) newline:false progress:progressDelta;
   )
   else
   (
      print "ERROR: loadMacroScripts() Failed"
      addStatusText (getString #failed) newline:false;
      installation_failed (getString #inst) \
                          (getString #loadMcr section:#Error) \
                          silent:silent;
      return false;
   )

   print "Assign hotkey"
   addStatusText (getString #assignHotkey);
   local showHelp = false;
   if (not (containsHotkeyAction "toggleSekai" "Sekai")) then
   (
      local queryStr   = getString #assignHotkey section:#Queries;
      local queryTitle = getString #assignHotkeyTitle section:#Queries
      local existingAction = getHotkeyAction();
      if (existingAction != undefined) do
      (
         if (existingAction.PersistentId != 0) then
         (
            if (existingAction.PersistentId == "50029" AND existingAction.TableId == 0) then
               queryStr += getString #replaceSelectByName section:#Queries;
            else
               queryStr += getString #replaceOtherHotkey section:#Queries;
         )
         else
         (
            queryStr += (getString #replaceOtherHotkey section:#Queries) + ":\n";
            queryStr += existingAction.MacroCategory + " - " + existingAction.MacroName;
         )
      )
      
      local do_assignHotkey = queryBox queryStr title:queryTitle;
      showHelp = not do_assignHotkey;
      
      if (not silent AND do_assignHotkey) then
      (
         if (assignHotkey()) then
         (
            print "Attempting to Assign Hotkey"
            addStatusText (getString #done) newline:false progress:progressDelta;
         )
         else
         (
            print "ERROR: assignHotkey() Failed"
            addStatusText (getString #failed) newline:false;
            installation_failed (getString #inst) \
                                (getString #assignHotkey section:#Error) \
                                silent:silent;
            return false;
         )
      )
      else
         addStatusText (getString #skipped) newline:false progress:progressDelta;
   )
   else
      addStatusText (getString #skipped) newline:false progress:progressDelta;
   
   print "Install Complete"
   setIsSekaiInstalled true;

   print "Show Complete MsgBox"
   installation_success (getString #inst) \
                        silent:silent \
                        showHowToUse:showHelp;
                        
   
   true;
),--End install function.


on create do
(
   clearTempDir();
   loadAssembly (tempDir + "/scripts/ScriptCenter.Max.dll");
)


)

sekaiInstaller = sekai_installer();