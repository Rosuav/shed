# -*- coding: utf-8 -*-
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: Protobufs/OakShared.proto
"""Generated protocol buffer code."""
from google.protobuf.internal import builder as _builder
from google.protobuf import descriptor as _descriptor
from google.protobuf import descriptor_pool as _descriptor_pool
from google.protobuf import symbol_database as _symbol_database
# @@protoc_insertion_point(imports)

_sym_db = _symbol_database.Default()




DESCRIPTOR = _descriptor_pool.Default().AddSerializedFile(b'\n\x19Protobufs/OakShared.proto\x12\x07OakSave\"\'\n\x04Vec3\x12\t\n\x01x\x18\x01 \x01(\x02\x12\t\n\x01y\x18\x02 \x01(\x02\x12\t\n\x01z\x18\x03 \x01(\x02\"=\n\x14GameStatSaveGameData\x12\x12\n\nstat_value\x18\x01 \x01(\x05\x12\x11\n\tstat_path\x18\x02 \x01(\t\"T\n\x19InventoryCategorySaveData\x12%\n\x1d\x62\x61se_category_definition_hash\x18\x01 \x01(\r\x12\x10\n\x08quantity\x18\x02 \x01(\x05\">\n\x12OakSDUSaveGameData\x12\x11\n\tsdu_level\x18\x01 \x01(\x05\x12\x15\n\rsdu_data_path\x18\x02 \x01(\t\"c\n!RegisteredDownloadableEntitlement\x12\n\n\x02id\x18\x01 \x01(\x05\x12\x10\n\x08\x63onsumed\x18\x02 \x01(\r\x12\x12\n\nregistered\x18\x03 \x01(\x08\x12\x0c\n\x04seen\x18\x04 \x01(\x08\"\xa6\x01\n\"RegisteredDownloadableEntitlements\x12%\n\x1d\x65ntitlement_source_asset_path\x18\x01 \x01(\t\x12\x17\n\x0f\x65ntitlement_ids\x18\x02 \x03(\x03\x12@\n\x0c\x65ntitlements\x18\x03 \x03(\x0b\x32*.OakSave.RegisteredDownloadableEntitlement\"T\n\x19\x43hallengeStatSaveGameData\x12\x1a\n\x12\x63urrent_stat_value\x18\x01 \x01(\x05\x12\x1b\n\x13\x63hallenge_stat_path\x18\x02 \x01(\t\"B\n\x1eOakChallengeRewardSaveGameData\x12 \n\x18\x63hallenge_reward_claimed\x18\x01 \x01(\x08\"\xc3\x02\n\x15\x43hallengeSaveGameData\x12\x17\n\x0f\x63ompleted_count\x18\x01 \x01(\x05\x12\x11\n\tis_active\x18\x02 \x01(\x08\x12\x1b\n\x13\x63urrently_completed\x18\x03 \x01(\x08\x12 \n\x18\x63ompleted_progress_level\x18\x04 \x01(\x05\x12\x18\n\x10progress_counter\x18\x05 \x01(\x05\x12?\n\x13stat_instance_state\x18\x06 \x03(\x0b\x32\".OakSave.ChallengeStatSaveGameData\x12\x1c\n\x14\x63hallenge_class_path\x18\x07 \x01(\t\x12\x46\n\x15\x63hallenge_reward_info\x18\x08 \x03(\x0b\x32\'.OakSave.OakChallengeRewardSaveGameData\"\xeb\x01\n\x0bOakMailItem\x12\x16\n\x0email_item_type\x18\x01 \x01(\r\x12\x1b\n\x13sender_display_name\x18\x02 \x01(\t\x12\x0f\n\x07subject\x18\x03 \x01(\t\x12\x0c\n\x04\x62ody\x18\x04 \x01(\t\x12\x1a\n\x12gear_serial_number\x18\x05 \x01(\t\x12\x11\n\tmail_guid\x18\x06 \x01(\t\x12\x11\n\tdate_sent\x18\x07 \x01(\x03\x12\x17\n\x0f\x65xpiration_date\x18\x08 \x01(\x03\x12\x16\n\x0e\x66rom_player_id\x18\t \x01(\t\x12\x15\n\rhas_been_read\x18\n \x01(\x08\"P\n\x1cOakCustomizationSaveGameData\x12\x0e\n\x06is_new\x18\x01 \x01(\x08\x12 \n\x18\x63ustomization_asset_path\x18\x02 \x01(\t\"T\n!OakInventoryCustomizationPartInfo\x12\x1f\n\x17\x63ustomization_part_hash\x18\x01 \x01(\r\x12\x0e\n\x06is_new\x18\x02 \x01(\x08\"\\\n&CrewQuartersDecorationItemSaveGameData\x12\x0e\n\x06is_new\x18\x01 \x01(\x08\x12\"\n\x1a\x64\x65\x63oration_item_asset_path\x18\x02 \x01(\t\"P\n CrewQuartersRoomItemSaveGameData\x12\x0e\n\x06is_new\x18\x01 \x01(\x08\x12\x1c\n\x14room_item_asset_path\x18\x02 \x01(\t\"\xfe\x01\n\x15VaultCardSaveGameData\x12!\n\x19last_active_vault_card_id\x18\x02 \x01(\r\x12\x18\n\x10\x63urrent_day_seed\x18\x03 \x01(\x05\x12\x19\n\x11\x63urrent_week_seed\x18\x04 \x01(\x05\x12K\n\x1evault_card_previous_challenges\x18\x05 \x03(\x0b\x32#.OakSave.VaultCardPreviousChallenge\x12@\n\x1avault_card_claimed_rewards\x18\x06 \x03(\x0b\x32\x1c.OakSave.VaultCardRewardList\":\n\x0fVaultCardReward\x12\x14\n\x0c\x63olumn_index\x18\x01 \x01(\x05\x12\x11\n\trow_index\x18\x02 \x01(\x05\"C\n\x13VaultCardGearReward\x12\x12\n\ngear_index\x18\x01 \x01(\x05\x12\x18\n\x10repurchase_count\x18\x02 \x01(\r\"\xcb\x02\n\x13VaultCardRewardList\x12\x15\n\rvault_card_id\x18\x01 \x01(\r\x12\x1d\n\x15vault_card_experience\x18\x02 \x01(\x03\x12\x36\n\x14unlocked_reward_list\x18\x04 \x03(\x0b\x32\x18.OakSave.VaultCardReward\x12\x36\n\x14redeemed_reward_list\x18\x05 \x03(\x0b\x32\x18.OakSave.VaultCardReward\x12\x19\n\x11vault_card_chests\x18\x07 \x01(\x05\x12 \n\x18vault_card_chests_opened\x18\x08 \x01(\r\x12\x1d\n\x15vault_card_keys_spent\x18\t \x01(\r\x12\x32\n\x0cgear_rewards\x18\n \x03(\x0b\x32\x1c.OakSave.VaultCardGearReward\"\\\n\x1aVaultCardPreviousChallenge\x12\x1f\n\x17previous_challenge_seed\x18\x01 \x01(\x05\x12\x1d\n\x15previous_challenge_id\x18\x02 \x01(\rb\x06proto3')

_builder.BuildMessageAndEnumDescriptors(DESCRIPTOR, globals())
_builder.BuildTopDescriptorsAndMessages(DESCRIPTOR, 'Protobufs.OakShared_pb2', globals())
if _descriptor._USE_C_DESCRIPTORS == False:

  DESCRIPTOR._options = None
  _VEC3._serialized_start=38
  _VEC3._serialized_end=77
  _GAMESTATSAVEGAMEDATA._serialized_start=79
  _GAMESTATSAVEGAMEDATA._serialized_end=140
  _INVENTORYCATEGORYSAVEDATA._serialized_start=142
  _INVENTORYCATEGORYSAVEDATA._serialized_end=226
  _OAKSDUSAVEGAMEDATA._serialized_start=228
  _OAKSDUSAVEGAMEDATA._serialized_end=290
  _REGISTEREDDOWNLOADABLEENTITLEMENT._serialized_start=292
  _REGISTEREDDOWNLOADABLEENTITLEMENT._serialized_end=391
  _REGISTEREDDOWNLOADABLEENTITLEMENTS._serialized_start=394
  _REGISTEREDDOWNLOADABLEENTITLEMENTS._serialized_end=560
  _CHALLENGESTATSAVEGAMEDATA._serialized_start=562
  _CHALLENGESTATSAVEGAMEDATA._serialized_end=646
  _OAKCHALLENGEREWARDSAVEGAMEDATA._serialized_start=648
  _OAKCHALLENGEREWARDSAVEGAMEDATA._serialized_end=714
  _CHALLENGESAVEGAMEDATA._serialized_start=717
  _CHALLENGESAVEGAMEDATA._serialized_end=1040
  _OAKMAILITEM._serialized_start=1043
  _OAKMAILITEM._serialized_end=1278
  _OAKCUSTOMIZATIONSAVEGAMEDATA._serialized_start=1280
  _OAKCUSTOMIZATIONSAVEGAMEDATA._serialized_end=1360
  _OAKINVENTORYCUSTOMIZATIONPARTINFO._serialized_start=1362
  _OAKINVENTORYCUSTOMIZATIONPARTINFO._serialized_end=1446
  _CREWQUARTERSDECORATIONITEMSAVEGAMEDATA._serialized_start=1448
  _CREWQUARTERSDECORATIONITEMSAVEGAMEDATA._serialized_end=1540
  _CREWQUARTERSROOMITEMSAVEGAMEDATA._serialized_start=1542
  _CREWQUARTERSROOMITEMSAVEGAMEDATA._serialized_end=1622
  _VAULTCARDSAVEGAMEDATA._serialized_start=1625
  _VAULTCARDSAVEGAMEDATA._serialized_end=1879
  _VAULTCARDREWARD._serialized_start=1881
  _VAULTCARDREWARD._serialized_end=1939
  _VAULTCARDGEARREWARD._serialized_start=1941
  _VAULTCARDGEARREWARD._serialized_end=2008
  _VAULTCARDREWARDLIST._serialized_start=2011
  _VAULTCARDREWARDLIST._serialized_end=2342
  _VAULTCARDPREVIOUSCHALLENGE._serialized_start=2344
  _VAULTCARDPREVIOUSCHALLENGE._serialized_end=2436
# @@protoc_insertion_point(module_scope)
