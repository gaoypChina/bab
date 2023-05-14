'use strict';

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const nodemailer = require('nodemailer');

admin.initializeApp();

const firestore = admin.firestore();

// Configure the email transport using the default SMTP transport.
const mailTransport = nodemailer.createTransport({
    host: 'ssl0.ovh.net',
    port: 465,
    secure: true,
    auth: {
        user: 'contact@beandbrew.com',
        pass: 'Yell0-Submarine'
    }
});

// Sends an email confirmation when a user changes his mailing list subscription.
exports.sendEmailConfirmation = functions.firestore.document('users/{uid}').onWrite(async( change, context) => {
    const newValue = change.after.exists ? change.after.data() : null;
    if (newValue == null) {
        return  null;
    }
    const previousValue = change.before.data();
    if (previousValue != null && newValue['subscribed'] === previousValue['subscribed']) {
        return null;
    }

    const mailOptions = {
        from: '"BeAndBrew" <noreply@beandbrew.com>',
        to: newValue['email'],
    };

    // Building Email message.
    mailOptions.subject = !newValue['subscribed'] ? 'Thanks and Welcome!' : 'Sad to see you go :`(';
    mailOptions.text = !newValue['subscribed'] ?
        'Thanks you for subscribing to our newsletter. You will receive our next weekly newsletter.' :
        'I hereby confirm that I will stop sending you the newsletter.';

    try {
        await mailTransport.sendMail(mailOptions);
        functions.logger.log(
            `New ${!newValue['subscribed'] ? '' : 'un'}subscription confirmation email sent to:`,
            newValue['email']
        );
    } catch(error) {
        functions.logger.error(
            'There was an error while sending the email:',
            error
        );
    }
    return null;
});

exports.updates = functions.https.onRequest(async (req, res) => {
    const collection = firestore.collection('yeasts');
    const snapshot = await collection.get();
    if (snapshot.empty) {
        console.log('No matching notifications.');
        return;
    }
    snapshot.forEach(async doc => {
        const rec = doc.data();
        if (rec.cells != null) {
            try {
                functions.logger.log(`Yeast:`, rec.name);
                rec.cells = rec.cells / 11.5;
                await doc.ref.set(rec);
            }
            catch (error) {
                functions.logger.error(
                    'There was an error update:',
                    error
                );
            }
        }
    });
    return null;
});