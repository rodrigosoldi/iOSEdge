//
//  ViewController.m
//  ViewTransition
//
//  Created by mangtronix on 12/13/13.
//  Copyright (c) 2013 mangtronix. All rights reserved.
//

#import "ViewController.h"

#import "ModalViewController.h"
#import "BEPModalTransitionAnimator.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (IBAction)showModalTapped:(id)sender
{
    ModalViewController *imageVC = [[ModalViewController alloc] init];
    imageVC.modalPresentationStyle = UIModalPresentationCustom;
    imageVC.transitioningDelegate = self;
    [self presentViewController:imageVC animated:YES completion:nil];
}

// Animation controller for presenting modal
- (id<UIViewControllerAnimatedTransitioning>) animationControllerForPresentedController:(UIViewController*)presented
presentingController:(UIViewController*)presenting
sourceController:(UIViewController*)source
{
    return [[BEPModalTransitionAnimator alloc] initWithDirection:BEPModelTransitionDirectionPresent];
}

// Animation controller for dismissing modal
- (id<UIViewControllerAnimatedTransitioning>) animationControllerForDismissedController:(UIViewController*)dismissed
{
    return [[BEPModalTransitionAnimator alloc] initWithDirection:BEPModelTransitionDirectionDismiss];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



@end
