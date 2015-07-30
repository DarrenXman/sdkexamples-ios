//
//  ChatViewController.m
//  ChatDemo-UI3.0
//
//  Created by dhc on 15/6/26.
//  Copyright (c) 2015年 easemob.com. All rights reserved.
//

#import "ChatViewController.h"

#import "UIViewController+HUD.h"
#import "NSDate+Category.h"

@interface ChatViewController ()<UIAlertViewDelegate>

@end

@implementation ChatViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [[EMSendMessageCell appearance] setBubbleBackgroundImage:[[UIImage imageNamed:@"chat_sender_bg"] stretchableImageWithLeftCapWidth:10 topCapHeight:35]];
    [[EMRecvMessageCell appearance] setBubbleBackgroundImage:[[UIImage imageNamed:@"chat_receiver_bg"] stretchableImageWithLeftCapWidth:35 topCapHeight:35]];
    
    [[EMSendMessageCell appearance] setMessageVoiceAnimationImages:@[[UIImage imageNamed:@"chat_sender_audio_playing_000"], [UIImage imageNamed:@"chat_sender_audio_playing_001"], [UIImage imageNamed:@"chat_sender_audio_playing_002"], [UIImage imageNamed:@"chat_sender_audio_playing_003"]]];
    [[EMRecvMessageCell appearance] setMessageVoiceAnimationImages:@[[UIImage imageNamed:@"chat_receiver_audio_playing000"], [UIImage imageNamed:@"chat_receiver_audio_playing001"], [UIImage imageNamed:@"chat_receiver_audio_playing002"], [UIImage imageNamed:@"chat_receiver_audio_playing003"]]];
    
    [self _setupBarButtonItem];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deleteAllMessages:) name:KNOTIFICATIONNAME_DELETEALLMESSAGE object:nil];
    
    //通过会话管理者获取已收发消息
    long long timestamp = self.conversation.latestMessage.timestamp + 1;
    [self loadMessagesFrom:timestamp count:self.pageCount append:NO];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - setup subviews

- (void)_setupBarButtonItem
{
    UIButton *backButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
    [backButton setImage:[UIImage imageNamed:@"back.png"] forState:UIControlStateNormal];
    [backButton addTarget:self action:@selector(backAction) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    [self.navigationItem setLeftBarButtonItem:backItem];
    
    //单聊
    if (self.conversation.conversationType == eConversationTypeChat) {
        UIButton *clearButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
        [clearButton setImage:[UIImage imageNamed:@"delete"] forState:UIControlStateNormal];
        [clearButton addTarget:self action:@selector(deleteAllMessages:) forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:clearButton];
    }
    else{//群聊
        UIButton *detailButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 60, 44)];
        [detailButton setImage:[UIImage imageNamed:@"group_detail"] forState:UIControlStateNormal];
        [detailButton addTarget:self action:@selector(showGroupDetailAction) forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:detailButton];
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.cancelButtonIndex != buttonIndex) {
        self.messageTimeIntervalTag = -1;
        [self.conversation removeAllMessages];
        [self.dataArray removeAllObjects];
        [self.messsagesSource removeAllObjects];
        
        [self.tableView reloadData];
    }
}

#pragma mark - EMMessageCellDelegate

- (void)imageMessageCellSelcted:(id<IMessageModel>)model
{
    
}

#pragma makr - private helper

- (BOOL)_shouldMarkMessageAsRead
{
    if (([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) || !self.isViewDidAppear)
    {
        return NO;
    }
    
    return YES;
}

#pragma mark - EaseMob

#pragma mark - EMChatManagerChatDelegate

- (void)didReceiveOfflineMessages:(NSArray *)offlineMessages
{
    if (![offlineMessages count])
    {
        return;
    }
    
    if ([self _shouldMarkMessageAsRead])
    {
        [self.conversation markAllMessagesAsRead:YES];
    }
    
    self.messageTimeIntervalTag = 0;
    long long timestamp = [[NSDate date] timeIntervalSince1970] * 1000 + 1;
    [self loadMessagesFrom:timestamp
                     count:[self.messsagesSource count] + [offlineMessages count]
                    append:NO];
}

-(void)didReceiveMessage:(EMMessage *)message
{
    if ([self.conversation.chatter isEqualToString:message.conversationChatter]) {
        [self addMessageToDataSource:message];
        
        if ([self shouldSendHasReadAckForMessage:message read:NO])
        {
            [self sendHasReadResponseForMessages:@[message]];
        }
        
        if ([self _shouldMarkMessageAsRead])
        {
            [self.conversation markMessageWithId:message.messageId asRead:YES];
        }
    }
}

-(void)didReceiveCmdMessage:(EMMessage *)message
{
    if ([self.conversation.chatter isEqualToString:message.conversationChatter]) {
        [self showHint:NSLocalizedString(@"receiveCmd", @"receive cmd message")];
    }
}

- (void)didReceiveMessageId:(NSString *)messageId
                    chatter:(NSString *)conversationChatter
                      error:(EMError *)error
{
    if (error && [self.conversation.chatter isEqualToString:conversationChatter]) {
        
        __weak ChatViewController *weakSelf = self;
        for (int i = 0; i < self.dataArray.count; i ++) {
            id object = [self.dataArray objectAtIndex:i];
            if ([object isKindOfClass:[EMMessageModel class]]) {
                EMMessageModel *model = [self.dataArray objectAtIndex:i];
                EMMessage *message = model.message;
                if ([messageId isEqualToString:message.messageId]) {
                    message.deliveryState = eMessageDeliveryState_Failure;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [weakSelf.tableView beginUpdates];
                        [weakSelf.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:i inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
                        [weakSelf.tableView endUpdates];
                        
                    });
                    
                    if (error && error.errorCode == EMErrorMessageContainSensitiveWords)
                    {
                        CGRect frame = self.chatToolbar.frame;
                        [self showHint:NSLocalizedString(@"message.forbiddenWords", @"Your message contains forbidden words") yOffset:-frame.size.height + 50];
                    }
                    break;
                }
            }
        }
    }
}

#pragma mark - EMChatManagerLoginDelegate

- (void)didLoginFromOtherDevice
{
    if ([self.imagePicker.mediaTypes count] > 0 && [[self.imagePicker.mediaTypes objectAtIndex:0] isEqualToString:(NSString *)kUTTypeMovie]) {
        [self.imagePicker stopVideoCapture];
    }
}

- (void)didRemovedFromServer
{
    if ([self.imagePicker.mediaTypes count] > 0 && [[self.imagePicker.mediaTypes objectAtIndex:0] isEqualToString:(NSString *)kUTTypeMovie]) {
        [self.imagePicker stopVideoCapture];
    }
}

#pragma mark - EMCallManagerCallDelegate

#pragma mark - action

- (void)backAction
{
    [[NSNotificationCenter defaultCenter] postNotificationName:KNOTIFICATIONNAME_RELOADCONLIST object:nil];
    
    if (self.deleteConversationIfNull) {
        //判断当前会话是否为空，若符合则删除该会话
        EMMessage *message = [self.conversation latestMessage];
        if (message == nil) {
            [[EaseMob sharedInstance].chatManager removeConversationByChatter:self.conversation.chatter deleteMessages:NO append2Chat:YES];
        }
    }
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)showGroupDetailAction
{
    [self.view endEditing:YES];
    if (self.conversation.conversationType == eConversationTypeGroupChat) {
        //        ChatGroupDetailViewController *detailController = [[ChatGroupDetailViewController alloc] initWithGroupId:_chatter];
        //        [self.navigationController pushViewController:detailController animated:YES];
    }
    else if (self.conversation.conversationType == eConversationTypeChatRoom)
    {
        //        ChatroomDetailViewController *detailController = [[ChatroomDetailViewController alloc] initWithChatroomId:_chatter];
        //        [self.navigationController pushViewController:detailController animated:YES];
    }
}

- (void)deleteAllMessages:(id)sender
{
    if (self.dataArray.count == 0) {
        [self showHint:NSLocalizedString(@"message.noMessage", @"no messages")];
        return;
    }
    
    if ([sender isKindOfClass:[NSNotification class]]) {
        NSString *groupId = (NSString *)[(NSNotification *)sender object];
        BOOL isDelete = [groupId isEqualToString:self.conversation.chatter];
        if (self.conversation.conversationType != eConversationTypeChat && isDelete) {
            self.messageTimeIntervalTag = -1;
            [self.conversation removeAllMessages];
            [self.messsagesSource removeAllObjects];
            [self.dataArray removeAllObjects];
            
            [self.tableView reloadData];
            [self showHint:NSLocalizedString(@"message.noMessage", @"no messages")];
        }
    }
    else if ([sender isKindOfClass:[UIButton class]]){
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"prompt", @"Prompt") message:NSLocalizedString(@"sureToDelete", @"please make sure to delete") delegate:self cancelButtonTitle:NSLocalizedString(@"cancel", @"Cancel") otherButtonTitles:NSLocalizedString(@"ok", @"OK"), nil];
        [alertView show];
    }
}


@end
