#!lua

-- This script is based on JustRon's scripts listisos.lu and bootiso.lua:
-- http://ubuntuforums.org/showthread.php?t=1288604
-- The original scripts were released into the public domain by JustRon and
-- I, Jordan Uggla, release this script into the public domain as well.

-- Detects the live system type and boots it
function iso_entry (isofile, langcode)
  if not mount_iso (isofile) then
    return false
  end
  if not langcode then
    langcode = "us"
  end

  --Linux shouldn't be passed the grub device name, just the relative path
  local relpath = isofile:match ("^%(.-%)(.*)$") or isofile
  local basename = basename (isofile)
  local loop_device = "(" .. basename .. ")"

  local loopbackcfg

  -- Any distro providing a loopback.cfg
  if (grub.file_exist (loop_device .. "/boot/grub/loopback.cfg")) then
    loopbackcfg = "/boot/grub/loopback.cfg"
  elseif (grub.file_exist (loop_device .. "/grub/loopback.cfg")) then
    loopbackcfg = "/grub/loopback.cfg"
  end

  if (loopbackcfg) then
    local title = "Boot " .. isofile
    local commands = "set iso_path='" .. relpath .. "'\nexport iso_path" ..
                     "\nset root='" .. loop_device .. "'" ..
                     "\nconfigfile " .. loopbackcfg
    grub.add_menu (commands, title)

  -- grml
  elseif (dir_exist (loop_device .. "/boot/grml")) then
    linux_entry (
      isofile,
      loop_device .. "/boot/grml/linux26", 
      loop_device .. "/boot/grml/initrd.gz",
      "findiso=" .. relpath .. " apm=power-off quiet boot=live nomce"
    )
  -- Parted Magic
  elseif (dir_exist (loop_device .. "/pmagic")) then
    linux_entry (
      isofile,
      loop_device .. "/pmagic/bzImage", 
      loop_device .. "/pmagic/initramfs",
      "iso_filename=" .. relpath .. 
        " edd=off noapic load_ramdisk=1 prompt_ramdisk=0 rw" .. 
        " sleep=10 loglevel=0 keymap=" .. langcode
    )
  -- Sidux
  elseif (dir_exist (loop_device .. "/sidux")) then
    linux_entry (
      isofile,
      find_file (loop_device .. "/boot", "vmlinuz%-.*%-sidux%-.*"), 
      find_file (loop_device .. "/boot", "initrd%.img%-.*%-sidux%-.*"),
      "fromiso=" .. relpath .. " boot=fll quiet"
    )
  -- Slax
  elseif (dir_exist (loop_device .. "/slax")) then
    linux_entry (
      isofile,
      loop_device .. "/boot/vmlinuz", 
      loop_device .. "/boot/initrd.gz",
      "from=" .. relpath .. " ramdisk_size=6666 root=/dev/ram0 rw"
    )
  -- Tinycore
  elseif (grub.file_exist (loop_device .. "/boot/tinycore.gz")) then
    linux_entry (
      isofile,
      loop_device .. "/boot/bzImage", 
      loop_device .. "/boot/tinycore.gz"
    )
  -- Ubuntu and Casper based Distros
  elseif (dir_exist (loop_device .. "/casper")) then
    linux_entry (
      isofile,
      loop_device .. "/casper/vmlinuz", 
      find_file (loop_device .. "/casper", "initrd%..z"),
      "boot=casper iso-scan/filename=" .. relpath .. 
        " quiet splash noprompt" .. 
        " keyb=" .. langcode .. 
        " debian-installer/language=" .. langcode .. 
        " console-setup/layoutcode?=" .. langcode .. 
        " --"
    )
  else
    error_entry (isofile, "Unsupported ISO type")
  end
end

-- Help function to get just the filename from a path
function basename (path)
  return path:match (".*/(.-)$")
end

-- Help function to show an error
function error_entry (isofile, msg)
  local title = "Error: " .. isofile .. " is not supported."

  local full_msg =
  "Error: " .. msg .. "\n\\nThe iso file " .. isofile .. " is not supported " ..
  "by Super GRUB2 disk. The most likely reason is that the iso is not loop " ..
  "bootable. An iso must be specifically designed to read its root " ..
  "filesystem from an iso file rather than looking for it in your CDROM " ..
  "drive. It is impossible to boot an iso file not specifically designed " ..
  "this way with GRUB or any other bootloader\n\\n" ..
  "If you believe that this iso file is loop bootable it is mounted as " ..
  "(" .. basename (isofile) .. ") so you can view its contents in the " ..
  "grub shell and try to boot it yourself. If there are any distributions " ..
  "that you know are loop bootable but are not currently supported by this " ..
  "script please check that you are using the latest version of Super GRUB2 " ..
  "Disk then send the commands required to boot the iso to " ..
  "supergrub-english@lists.berlios.de so support can be added. Or even " ..
  "better, convince them to ship a loopback.cfg on their isos: \n\\n" ..
  "www.supergrubdisk.org/wiki/Loopback.cfg for more info"

  local commands = 'echo -e "' .. full_msg .. '"'

  grub.add_menu (commands, title)
end

-- Help function to search for a file
function find_file (folder, match)
  local filename

  local function enum_file (name)
    if (filename == nil) then
      filename = string.match (name, match)
    end
  end

  grub.enum_file (enum_file, folder)

  if (filename) then
    return folder .. "/" .. filename
  else
    return nil
  end
end

-- Help function to check if a directory exist
function dir_exist (dir)
  return (grub.run("test -d '" .. dir .. "'") == 0)
end

-- Adds a menu entry for a GNU/Linux live system
function linux_entry (isofile, linux, initrd, params)
  -- Sometimes a distribution may have been correctly detected, but that
  -- distribution may have changed how they name their kernel and initrd since
  -- this script was made. If so linux or initrd may be nil and we should
  -- present an error.
  if not linux and initrd then
    error_entry (isofile, "Unsupported ISO type")
    return false
  end

  local commands = ""
  local title = "Boot " .. isofile
  if (linux and grub.file_exist (linux)) then
    if (initrd and grub.file_exist (initrd)) then
      if (params) then
        commands = commands .. "linux " .. linux .. " " .. params .. "\n"
      else
        commands = commands .. "linux " .. linux .. "\n"
      end
      commands = commands .. "initrd " .. initrd .. "\n"
    else
      error_entry (isofile, "cannot find initrd file '" .. initrd .. "'")
    end
    grub.add_menu (commands, title)
  else
    error_entry (isofile, "cannot find linux file '" .. initrd .. "'")
  end
end

-- Checks that filename contains only allowed characters
function filename_allowed (isofile)
  local allowed_chars = '%w_%-%./'

  -- Remove device, if any, from path.
  -- Device names contain parens, which are not allowed in the filename itself
  local isofile = isofile:match ("^%(.-%)(.*)$") or isofile

  if (isofile:match ("^[" .. allowed_chars .. "]*$")) then
    return true;
  end

  local title = "Error: " .. isofile .. " has unallowed characters"

  local message = 'Only alphanumeric characters, periods, underscores, ' ..
                  'and dashes are allowed as part of an iso filename. ' ..
                  'The exact lua patter for allowed characters is "' ..
                  allowed_chars .. '"'
  local command = "echo '" .. message .. "'"

  grub.add_menu (command, title)

  return false
end

-- Mounts the iso file
function mount_iso (isofile)
  local result = false

  if not filename_allowed (isofile) then
    return false
  end

  if (isofile == nil) then
    error_entry (isofile, "variable 'isofile' is undefined")
  elseif (not grub.file_exist (isofile)) then
    error_entry (isofile, "Cannot find isofile '" .. isofile .. "'")
  else
    local basename = basename (isofile)
    local err_no, err_msg = grub.run ("loopback " .. basename .. " " .. isofile)
    if (err_no ~= 0) then
      error_entry (isofile, "Cannot load ISO: " .. err_msg)
    else
      result = true
    end
  end

  return result
end

langcode = grub.getenv("lang")
isofolder = grub.getenv("isofolder")
if (isofolder == nil) then
  isofolder = "/boot-isos"
end

num_isos_found = 0
function enum_device (device, fs, uuid)
  local isofolder = isofolder

  function enum_file (name)

    if string.find (name, ".*%.[iI][sS][oO]") then
      local isofile = "(" .. device .. ")" .. isofolder .. "/" .. name
      iso_entry (isofile, langcode)
      num_isos_found = num_isos_found + 1
    end
  end

  grub.enum_file (enum_file, "(" .. device .. ")" .. isofolder)
  isofolder = "/boot" .. isofolder
  grub.enum_file (enum_file, "(" .. device .. ")" .. isofolder)
end

grub.enum_device (enum_device)

if (num_isos_found < 1) then
  print ("Error: No iso files were found in " .. isofolder .. " or " .. "/boot" ..
         isofolder .. " on any devices.\n" .. "If you would like this " ..
	 "script to search for a different directory, set the environment " ..
	 "variable $isofolder.")
end